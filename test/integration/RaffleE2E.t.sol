// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Helper} from "../../script/Helper.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleE2ETest is Test, Helper {
    Raffle public raffle;
    Config public config;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    // Participants
    address public participant1 = makeAddr("participant1");
    address public participant2 = makeAddr("participant2");
    address public participant3 = makeAddr("participant3");
    address public participant4 = makeAddr("participant4");

    // Funds
    uint256 public constant PARTICIPANT_FUNDS = 10 ether;

    event WinnerPicked(address indexed _winner);

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, config) = deployer.deployContract();

        vrfCoordinator = VRFCoordinatorV2_5Mock(config._vrfCoordinator);

        // Fund participants
        vm.deal(participant1, PARTICIPANT_FUNDS);
        vm.deal(participant2, PARTICIPANT_FUNDS);
        vm.deal(participant3, PARTICIPANT_FUNDS);
        vm.deal(participant4, PARTICIPANT_FUNDS);

        // Fund the VRF subscription (required for mock)
        vrfCoordinator.fundSubscription(config._subscriptionId, 100 ether);
    }

    function test_E2E_FullRaffleCycle() public {
        // ============ ROUND 1 ============
        console.log("=== Starting Round 1 ===");
        console.log("Initial currentRound:", raffle.currentRound());

        // 1. Multiple participants enter raffle
        vm.prank(participant1);
        raffle.enterRaffle{value: config._entranceFee}();

        vm.prank(participant2);
        raffle.enterRaffle{value: config._entranceFee}();

        vm.prank(participant3);
        raffle.enterRaffle{value: config._entranceFee}();

        // Verify entries
        (, , , uint256 totalEntries, uint256 totalAmount, , , ) = raffle.getRound(0);
        assertEq(totalEntries, 3);
        assertEq(totalAmount, config._entranceFee * 3);
        assertEq(uint256(raffle.raffleState()), uint256(Raffle.State.OPEN));

        // 2. Fast forward time past round interval
        vm.warp(block.timestamp + config._roundInterval + 1);
        vm.roll(block.number + 1);

        // 3. Check upkeep returns true
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 4. Perform upkeep (triggers VRF request)
        raffle.performUpkeep("");
        assertEq(uint256(raffle.raffleState()), uint256(Raffle.State.CALCULATING));

        // 5. Get the VRF request ID
        (, , , , , , uint256 requestId, ) = raffle.getRound(0);
        assertTrue(requestId > 0);

        // 6. Record balances before winner selection
        uint256 participant1BalanceBefore = participant1.balance;
        uint256 participant2BalanceBefore = participant2.balance;
        uint256 participant3BalanceBefore = participant3.balance;

        // 7. Fulfill VRF request (mock)
        vm.recordLogs();
        vrfCoordinator.fulfillRandomWords(requestId, address(raffle));
        console.log("After fulfillRandomWords, currentRound:", raffle.currentRound());

        // 8. Verify winner was picked and paid
        assertEq(uint256(raffle.raffleState()), uint256(Raffle.State.OPEN));
        assertEq(raffle.currentRound(), 1); // New round started

        // 9. Check that exactly one participant received the prize
        uint256 participant1BalanceAfter = participant1.balance;
        uint256 participant2BalanceAfter = participant2.balance;
        uint256 participant3BalanceAfter = participant3.balance;

        bool participant1Won = participant1BalanceAfter > participant1BalanceBefore;
        bool participant2Won = participant2BalanceAfter > participant2BalanceBefore;
        bool participant3Won = participant3BalanceAfter > participant3BalanceBefore;

        // Exactly one winner
        uint256 winnersCount = (participant1Won ? 1 : 0) + (participant2Won ? 1 : 0) + (participant3Won ? 1 : 0);
        assertEq(winnersCount, 1);

        // Winner received correct amount
        uint256 prizeAmount = config._entranceFee * 3;
        if (participant1Won) {
            assertEq(participant1BalanceAfter - participant1BalanceBefore, prizeAmount);
            console.log("Participant 1 won!");
        } else if (participant2Won) {
            assertEq(participant2BalanceAfter - participant2BalanceBefore, prizeAmount);
            console.log("Participant 2 won!");
        } else {
            assertEq(participant3BalanceAfter - participant3BalanceBefore, prizeAmount);
            console.log("Participant 3 won!");
        }

        // ============ ROUND 2 ============
        console.log("=== Starting Round 2 ===");

        // 10. Verify new round started with clean slate
        (, , , uint256 round2Entries, uint256 round2Amount, , , ) = raffle.getRound(1);
        assertEq(round2Entries, 0);
        assertEq(round2Amount, 0);

        // 11. New participants can enter
        vm.prank(participant4);
        raffle.enterRaffle{value: config._entranceFee * 2}();

        vm.prank(participant1);
        raffle.enterRaffle{value: config._entranceFee}();

        (, , , round2Entries, round2Amount, , , ) = raffle.getRound(1);
        assertEq(round2Entries, 2);
        assertEq(round2Amount, config._entranceFee * 3);

        console.log("=== E2E Test Complete ===");
    }

    function test_E2E_RaffleWithNoEntries() public {
        // Fast forward time
        vm.warp(block.timestamp + config._roundInterval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep
        raffle.performUpkeep("");

        (, , , , , , uint256 requestId, ) = raffle.getRound(0);

        // Fulfill VRF request with no entries
        vrfCoordinator.fulfillRandomWords(requestId, address(raffle));

        // Should start new round without errors
        assertEq(uint256(raffle.raffleState()), uint256(Raffle.State.OPEN));
        assertEq(raffle.currentRound(), 1);

        // Verify no winner was set
        (, , , , , uint256 winner, , ) = raffle.getRound(0);
        assertEq(winner, 0);
    }
}
