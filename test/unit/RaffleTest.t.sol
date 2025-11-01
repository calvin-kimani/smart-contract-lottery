// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Helper} from "../../script/Helper.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract RaffleTest is Test, Helper {
    Raffle public raffle;
    Config public config;

    // Participants
    address public participant1 = makeAddr("participant1");
    address public participant2 = makeAddr("participant2");
    address public participant3 = makeAddr("participant3");

    // Funds
    uint256 public constant PARTICIPANT_1_FUNDS = 10 ether;
    uint256 public constant PARTICIPANT_2_FUNDS = 10 ether;
    uint256 public constant PARTICIPANT_3_FUNDS = 10 ether;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, config) = deployer.deployContract();

        // Fund participants
        vm.deal(participant1, PARTICIPANT_1_FUNDS);
        vm.deal(participant2, PARTICIPANT_2_FUNDS);
        vm.deal(participant3, PARTICIPANT_3_FUNDS);
    }

    function test_InitialRaffleState() public view {
        assert(raffle.raffleState() == Raffle.State.OPEN);
    }

    /**
     * Enter Raffle
     */
    function test_EnterRaffleSuccessfully() public {
        vm.startPrank(participant1);
        raffle.enterRaffle{value: config._entranceFee}();
        vm.stopPrank();

        (uint256 id, , , uint256 totalEntries, , , , ) = raffle.getRound(
            raffle.currentRound()
        );

        address[] memory players = raffle.getPlayers(id);

        assertEq(totalEntries, players.length);
        assertEq(participant1, players[0]);
    }

    function test_RevertEnterRaffleWhileStateClosed() public {
        vm.prank(raffle.I_OWNER());
        raffle.closeRaffle();

        vm.prank(participant1);
        vm.expectRevert(Raffle.Raffle__ErrRaffleNotOpen.selector);
        raffle.enterRaffle{value: config._entranceFee}();
    }

    function test_RevertEnterRaffleInsufficientEntranceFee() public {
        vm.prank(participant1);
        vm.expectRevert(Raffle.Raffle__ErrInsufficientEntranceFee.selector);

        raffle.enterRaffle();
    }

    function test_RevertEnterRaffleWhileStateCalculating() public {
        vm.prank(participant1);
        raffle.enterRaffle{value: config._entranceFee}();

        vm.prank(participant2);
        raffle.enterRaffle{value: config._entranceFee}();

        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__ErrRaffleNotOpen.selector);
        vm.prank(participant3);
        raffle.enterRaffle{value: config._entranceFee}();
    }

    /**
     * Modifiers
     */
    function test_isOwner_RevertsIfNotOwner() public {
        vm.startPrank(participant1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__ErrSenderNotOwner.selector,
                participant1,
                raffle.I_OWNER()
            )
        );

        raffle.closeRaffle();
        vm.stopPrank();
    }

    function test_isOwner_Success() public {
        vm.prank(raffle.I_OWNER());

        // owner only function
        raffle.closeRaffle();

        assert(raffle.raffleState() == Raffle.State.CLOSED);
    }

    /**
     * Check Upkeep
     */
    function test_UpkeepNeededEnoughTimePassed() public {
        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == true);
    }

    function test_UpkeepNotNeededNotEnoughTimePassed() public {
        (, , uint256 endTime, , , , , ) = raffle.getRound(
            raffle.currentRound()
        );
        vm.warp(endTime - 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded == false);
    }

    function test_UpkeepNeededRaffleStateOpen() public {
        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffle.raffleState() == Raffle.State.OPEN);
        assert(upkeepNeeded == true);
    }

    function test_UpkeepNotNeededRaffleStateClosed() public {
        vm.prank(raffle.I_OWNER());
        raffle.closeRaffle();

        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(raffle.raffleState() == Raffle.State.CLOSED);
        assert(upkeepNeeded == false);
    }

    /*
     * Perform Upkeep
     */
    function test_performUpkeep_FailsIfUpkeepNotNeeded() public {
        (, , uint256 endTime, , , , , ) = raffle.getRound(
            raffle.currentRound()
        );
        vm.warp(endTime - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__ErrUpkeepNotNeeded.selector,
                block.timestamp,
                endTime,
                Raffle.State.OPEN
            )
        );
        raffle.performUpkeep("");
    }

    function test_performUkeep_Success() public {
        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        assert(raffle.raffleState() == Raffle.State.CALCULATING);
    }

    /**
     * Roll Dice
     */
    function test_rollDice_EmitsRequestId() public {
        vm.prank(participant1);
        raffle.enterRaffle{value: config._entranceFee}();

        vm.warp(block.timestamp + config._roundInterval + 10 seconds);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        (, , , , , , uint256 roundRequestId, ) = raffle.getRound(
            raffle.currentRound()
        );

        assert(raffle.raffleState() == Raffle.State.CALCULATING);
        assertEq(uint256(requestId), roundRequestId);
    }

    /**
     * Fuzz Tests
     */
    function testFuzz_EnterRaffleWithVariousAmounts(uint256 amount) public {
        // Bound amount between entrance fee and participant's balance
        amount = bound(amount, config._entranceFee, PARTICIPANT_1_FUNDS);

        vm.prank(participant1);
        raffle.enterRaffle{value: amount}();

        (, , , uint256 totalEntries, uint256 totalAmount, , , ) = raffle.getRound(
            raffle.currentRound()
        );

        assertEq(totalEntries, 1);
        assertEq(totalAmount, amount);
    }
}
