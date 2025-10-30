// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {Helper} from "./Helper.s.sol";

contract DeployRaffle is Script, Helper {
    Raffle public raffle;

    function run() public returns (Raffle, Config memory) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, Config memory) {
        Config memory config = getConfig();

        vm.startBroadcast();
        raffle = new Raffle(
            config._entranceFee,
            config._roundInterval,
            config._vrfCoordinator,
            config._keyHash,
            config._subscriptionId
        );
        vm.stopBroadcast();

        return (raffle, config);
    }
}
