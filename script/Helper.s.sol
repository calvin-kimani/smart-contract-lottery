// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 0.000000001 LINK per gas
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 1e18; //
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
}

contract Helper is Script, CodeConstants {
    struct Config {
        uint256 _entranceFee;
        uint256 _roundInterval;
        address _vrfCoordinator;
        bytes32 _keyHash;
        uint256 _subscriptionId;
    }

    Config networkConfig;
    mapping(uint256 chainId => Config) public networkConfigs;

    constructor() {
        networkConfigs[LOCAL_CHAIN_ID] = localConfig();
        networkConfigs[SEPOLIA_CHAIN_ID] = sepoliaConfig();
    }

    function getConfig() public view returns (Config memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return networkConfigs[SEPOLIA_CHAIN_ID];
        }

        return networkConfigs[LOCAL_CHAIN_ID];
    }

    function sepoliaConfig() public pure returns (Config memory) {
        return Config({
            _entranceFee: 0.0001 ether,
            _roundInterval: 10 seconds,
            _vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            _keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            _subscriptionId: 0
        });
    }

    function localConfig() public returns (Config memory) {
        if (address(networkConfigs[LOCAL_CHAIN_ID]._vrfCoordinator) != address(0)) {
            return networkConfigs[LOCAL_CHAIN_ID];
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);

        vm.stopBroadcast();

        return Config({
            _entranceFee: 0.01 ether,
            _roundInterval: 10 seconds,
            _vrfCoordinator: address(vrfCoordinatorMock),
            _keyHash: bytes32(0),
            _subscriptionId: 0
        });
    }
}
