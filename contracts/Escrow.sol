// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IEscrow } from "./interfaces/IEscrow.sol";

contract Escrow is IEscrow {
    address public immutable i_arbiter;
    uint256 private s_nextEscrowId;
    mapping(uint256 => EscrowDetails) private s_escrows;

    modifier escrowExists(uint256 id) {
        if (s_escrows[id].payer == address(0)) {
            revert Escrow__NotFound(id);
        }
        _;
    }

    modifier inStatus(uint256 id, Status requiredStatus) {
        uint8 currentStatus = s_escrows[id].status;
        if (currentStatus != uint8(requiredStatus)) {
            revert Escrow__InvalidState(id, currentStatus, uint8(requiredStatus));
        }
        _;
    }

    modifier onlyArbiter() {
        if (msg.sender != i_arbiter) {
            revert Escrow__NotArbiter(msg.sender, i_arbiter);
        }
        _;
    }

    enum Status {
        Created,
        Released,
        Refunded,
        Resolved
    }

    constructor(address arbiter) {
        i_arbiter = arbiter;
    }

    function createEscrow(address payee, bytes32 hashlock, uint64 timelock)
        external
        payable
        override
        returns (uint256 id)
    {
        if (msg.value == 0) {
            revert Escrow__ValueMustBePositive();
        }
        if (payee == address(0)) {
            revert Escrow__InvalidPayee();
        }
        if (timelock <= block.timestamp) {
            revert Escrow__TimelockNotInFuture(timelock, uint64(block.timestamp));
        }

        id = s_nextEscrowId;
        s_escrows[id] = EscrowDetails({
            payer: msg.sender,
            payee: payee,
            value: msg.value,
            hashlock: hashlock,
            timelock: timelock,
            status: uint8(Status.Created)
        });

        s_nextEscrowId++;
        emit EscrowCreated(id, msg.sender, payee, msg.value, hashlock, timelock);
    }

    function release(uint256 id, bytes calldata preimage)
        external
        override
        escrowExists(id)
        inStatus(id, Status.Created)
    {
        EscrowDetails storage escrow = s_escrows[id];

        if (keccak256(preimage) != escrow.hashlock) {
            revert Escrow__InvalidPreimage(id);
        }

        escrow.status = uint8(Status.Released);
        emit EscrowReleased(id, preimage);

        (bool success,) = escrow.payee.call{ value: escrow.value }("");
        if (!success) {
            revert Escrow__TransferFailed(id, escrow.payee, escrow.value);
        }
    }

    function refund(uint256 id) external override escrowExists(id) inStatus(id, Status.Created) {
        EscrowDetails storage escrow = s_escrows[id];

        if (msg.sender != escrow.payer) {
            revert Escrow__NotThePayer(msg.sender, escrow.payer);
        }
        if (block.timestamp < escrow.timelock) {
            revert Escrow__TimelockNotExpired(block.timestamp, escrow.timelock);
        }

        escrow.status = uint8(Status.Refunded);
        emit EscrowRefunded(id);

        (bool success,) = escrow.payer.call{ value: escrow.value }("");
        if (!success) {
            revert Escrow__TransferFailed(id, escrow.payer, escrow.value);
        }
    }

    function resolve(uint256 id, bool toPayee)
        external
        override
        onlyArbiter
        escrowExists(id)
        inStatus(id, Status.Created)
    {
        EscrowDetails storage escrow = s_escrows[id];

        address winner = toPayee ? escrow.payee : escrow.payer;

        escrow.status = uint8(Status.Resolved);
        emit EscrowResolved(id, winner);

        (bool success,) = winner.call{ value: escrow.value }("");
        if (!success) {
            revert Escrow__TransferFailed(id, winner, escrow.value);
        }
    }

    function getEscrow(uint256 id) external view returns (EscrowDetails memory) {
        return s_escrows[id];
    }

    function getNextEscrowId() external view returns (uint256) {
        return s_nextEscrowId;
    }
}
