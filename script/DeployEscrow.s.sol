// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { Script, console } from "forge-std/Script.sol";
import { Escrow } from "../contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run() external returns (Escrow) {
        address arbiter = vm.envAddress("ARBITER_ADDRESS");
        vm.startBroadcast();
        Escrow escrow = new Escrow(arbiter);
        vm.stopBroadcast();

        console.log("Escrow deployed at:", address(escrow));
        console.log("Arbiter:", arbiter);

        return escrow;
    }
}
