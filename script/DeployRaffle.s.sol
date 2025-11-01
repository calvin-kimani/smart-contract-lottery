// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {Helper} from "./Helper.s.sol";
import {Interactions} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    Raffle public raffle;
    Interactions public interactions;
    Helper public helper;

    constructor() {
        interactions = new Interactions();
        helper = new Helper();
    }

    function run() public returns (Raffle, Helper.Config memory) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, Helper.Config memory) {
        Helper.Config memory config = helper.getConfig();
        uint256 subId = config._subscriptionId;
        address account = config._account;

        if (subId == 0) {
            subId = interactions._createSubscription(
                config._vrfCoordinator,
                account
            );
            interactions._fundSubscription(
                subId,
                3,
                config._vrfCoordinator,
                config._linkToken,
                account
            );
            config._subscriptionId = subId; // Update config with new subscription ID
        }

        vm.startBroadcast(account);
        raffle = new Raffle(
            config._entranceFee,
            config._roundInterval,
            config._vrfCoordinator,
            config._keyHash,
            subId
        );
        vm.stopBroadcast();

        interactions.addConsumerToSubscription(
            subId,
            address(raffle),
            config._vrfCoordinator,
            account
        );

        return (raffle, config);
    }
}
