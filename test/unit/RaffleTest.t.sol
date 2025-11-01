// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
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

    function test_OwnerIsSetCorrectly() public view {
        assert(raffle.I_OWNER() == msg.sender);
    }

    function test_InitialRaffleState() public view {
        assert(raffle.raffleState() == Raffle.State.OPEN);
    }

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

    function test_EnterRaffleWhileStateClosed() public {
        vm.prank(raffle.I_OWNER());
        raffle.closeRaffle();

        vm.prank(participant1);
        vm.expectRevert(Raffle.Raffle__ErrRaffleNotOpen.selector);

        raffle.enterRaffle{value: raffle.I_ENTRANCE_FEE()}();
    }

    function test_EnterRaffleInsufficientEntranceFee() public {
        vm.prank(participant1);
        vm.expectRevert(Raffle.Raffle__ErrInsufficientEntranceFee.selector);

        raffle.enterRaffle();
    }

    function test_EnterRaffleWhileStateCalculating() public {
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
}
