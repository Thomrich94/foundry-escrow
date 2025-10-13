// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IEscrow } from "./interface/IEscrow.sol";

contract Escrow is IEscrow {
    address public immutable arbiter;

    error Escrow__ValueMustBePositive();
    error Escrow__InvalidPayee();
    error Escrow__TimelockNotInFuture(uint64 providedTimelock, uint64 currentTimestamp);

    enum Status {
        Created,
        Released,
        Refunded,
        Resolved
    }

    constructor(address _arbiter) {
        arbiter = _arbiter;
    }

    function createEscrow(address payee, bytes32 hashlock, uint64 timelock) external payable returns (uint256 id) {}
    function release(uint256 id, bytes calldata preimage) external {}
    function refund(uint256 id) external {}
    function resolve(uint256 id, bool toPayee) external {}
    function getEscrow(uint256 id) external view returns (EscrowDetails memory) {}
}
