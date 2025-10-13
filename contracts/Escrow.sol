// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IEscrow } from "./interface/IEscrow.sol";

contract Escrow is IEscrow {
    address public immutable arbiter;
    uint256 private nextEscrowId;
    mapping(uint256 => EscrowDetails) private escrows;

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

    function createEscrow(address payee, bytes32 hashlock, uint64 timelock) external payable returns (uint256 id) {
        if (msg.value == 0) {
            revert Escrow__ValueMustBePositive();
        }
        if (payee == address(0)) {
            revert Escrow__InvalidPayee();
        }
        if (timelock <= block.timestamp) {
            revert Escrow__TimelockNotInFuture(timelock, uint64(block.timestamp));
        }

        id = nextEscrowId;
        escrows[id] = EscrowDetails({
            payer: msg.sender,
            payee: payee,
            value: msg.value,
            hashlock: hashlock,
            timelock: timelock,
            status: uint8(Status.Created)
        });

        nextEscrowId++;
        emit EscrowCreated(id, msg.sender, payee, msg.value, hashlock, timelock);
    }

    function release(uint256 id, bytes calldata preimage) external { }
    function refund(uint256 id) external { }
    function resolve(uint256 id, bool toPayee) external { }

    function getEscrow(uint256 id) external view returns (EscrowDetails memory) {
        return escrows[id];
    }
}
