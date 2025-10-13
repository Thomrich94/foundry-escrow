// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { Script } from "forge-std/Script.sol";
import { Escrow } from "../contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run(address _arbiter) external returns (Escrow) {
        vm.startBroadcast();
        Escrow escrow = new Escrow(_arbiter);
        vm.stopBroadcast();

        return escrow;
    }
}
