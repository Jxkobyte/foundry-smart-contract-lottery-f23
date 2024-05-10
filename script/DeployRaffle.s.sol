// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {

    function run() external returns (Raffle, HelperConfig) {
        HelperConfig hc = new HelperConfig();
        (uint256 ticketFee,
        uint256 drawInterval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit) = hc.activeNetworkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(ticketFee, drawInterval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();
        return (raffle, hc);

    }
}