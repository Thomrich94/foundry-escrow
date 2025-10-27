// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IEscrow } from "./interface/IEscrow.sol";

contract Escrow is IEscrow {
    address public immutable i_arbiter;
    uint256 private s_nextEscrowId;
    mapping(uint256 => EscrowDetails) private s_escrows;

    error Escrow__ValueMustBePositive();
    error Escrow__InvalidPayee();
    error Escrow__TimelockNotInFuture(uint64 providedTimelock, uint64 currentTimestamp);
    error Escrow__NotFound(uint256 id);
    error Escrow__InvalidState(uint256 id, uint8 currentStatus, uint8 requiredStatus);
    error Escrow__InvalidPreimage(uint256 id);
    error Escrow__TransferFailed(uint256 id, address receiver, uint256 value);
    error Escrow__NotThePayer(address caller, address expectedPayer);
    error Escrow__TimelockNotExpired(uint256 blockTimestamp, uint64 escrowTimelock);
    error Escrow__NotArbiter(address caller, address arbiter);

    modifier escrowExists(uint256 _id) {
        if (s_escrows[_id].payer == address(0)) {
            revert Escrow__NotFound(_id);
        }
        _;
    }

    modifier inStatus(uint256 _id, Status _requiredStatus) {
        uint8 currentStatus = s_escrows[_id].status;
        if (currentStatus != uint8(_requiredStatus)) {
            revert Escrow__InvalidState(_id, currentStatus, uint8(_requiredStatus));
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

    constructor(address _arbiter) {
        i_arbiter = _arbiter;
    }

    function createEscrow(address _payee, bytes32 _hashlock, uint64 _timelock) external payable returns (uint256 id) {
        if (msg.value == 0) {
            revert Escrow__ValueMustBePositive();
        }
        if (_payee == address(0)) {
            revert Escrow__InvalidPayee();
        }
        if (_timelock <= block.timestamp) {
            revert Escrow__TimelockNotInFuture(_timelock, uint64(block.timestamp));
        }

        id = s_nextEscrowId;
        s_escrows[id] = EscrowDetails({
            payer: msg.sender,
            payee: _payee,
            value: msg.value,
            hashlock: _hashlock,
            timelock: _timelock,
            status: uint8(Status.Created)
        });

        s_nextEscrowId++;
        emit EscrowCreated(id, msg.sender, _payee, msg.value, _hashlock, _timelock);
    }

    function release(uint256 _id, bytes calldata _preimage) external escrowExists(_id) inStatus(_id, Status.Created) {
        EscrowDetails storage escrow = s_escrows[_id];

        if (keccak256(_preimage) != escrow.hashlock) {
            revert Escrow__InvalidPreimage(_id);
        }

        escrow.status = uint8(Status.Released);
        emit EscrowReleased(_id, _preimage);

        (bool success,) = escrow.payee.call{ value: escrow.value }("");
        if (!success) {
            revert Escrow__TransferFailed(_id, escrow.payee, escrow.value);
        }
    }

    function refund(uint256 _id) external escrowExists(_id) inStatus(_id, Status.Created) {
        EscrowDetails storage escrow = s_escrows[_id];

        if (msg.sender != escrow.payer) {
            revert Escrow__NotThePayer(msg.sender, escrow.payer);
        }
        if (block.timestamp < escrow.timelock) {
            revert Escrow__TimelockNotExpired(block.timestamp, escrow.timelock);
        }

        escrow.status = uint8(Status.Refunded);
        emit EscrowRefunded(_id);

        (bool success,) = escrow.payer.call{ value: escrow.value }("");
        if (!success) {
            revert Escrow__TransferFailed(_id, escrow.payer, escrow.value);
        }
    }

    function resolve(uint256 _id, bool _toPayee) external onlyArbiter escrowExists(_id) inStatus(_id, Status.Created) {
        EscrowDetails storage escrow = s_escrows[_id];

        address winner = _toPayee ? escrow.payee : escrow.payer;

        escrow.status = uint8(Status.Resolved);
        emit EscrowResolved(_id, winner);

        (bool success, ) = winner.call{value: escrow.value}("");
        if (!success) {
            revert Escrow__TransferFailed(_id, winner, escrow.value);
        }
     }

    function getEscrow(uint256 id) external view returns (EscrowDetails memory) {
        return s_escrows[id];
    }

    function getNextEscrowId() external view returns (uint256) {
        return s_nextEscrowId;
    }
}
