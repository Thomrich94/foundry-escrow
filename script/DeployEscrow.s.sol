// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { Script, console } from "forge-std/Script.sol";
import { Escrow } from "../contracts/Escrow.sol";

contract DeployEscrow is Script {
    function run(address arbiter) external returns (Escrow) {
        vm.startBroadcast();
        Escrow escrow = new Escrow(arbiter);
        vm.stopBroadcast();

        console.log("Escrow deployed at:", address(escrow));
        console.log("Arbiter:", arbiter);

        return escrow;
    }
}
