// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {CodeConstants} from "./Helper.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract Interactions is Script, CodeConstants {
    function _createSubscription(
        address _vrfCoordinator
    ) public returns (uint256) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        return subId;
    }

    function _fundSubscription(
        uint256 _subId,
        uint96 _amount,
        address _vrfCoordinator,
        address _linkToken
    ) public {
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subId,
                _amount
            );
            vm.stopBroadcast();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                _amount,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
        }
    }

    /**
     * Adds a consumer to the subscription.
     * @param _raffleAddress The address of the Raffle contract to be added as a consumer.
     */
    function addConsumerToSubscription(
        uint256 _subId,
        address _raffleAddress,
        address _vrfCoordinator
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(
            _subId,
            _raffleAddress
        );
        vm.stopBroadcast();
    }
}
