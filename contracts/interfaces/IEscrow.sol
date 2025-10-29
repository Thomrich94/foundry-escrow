// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IEscrow {
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
    error Escrow__ResolutionNotApproved(uint256 id);

    event EscrowCreated(
        uint256 indexed id,
        address indexed payer,
        address indexed payee,
        uint256 value,
        bytes32 hashlock,
        uint64 timelock
    );
    event EscrowReleased(uint256 indexed id, bytes preimage);
    event EscrowRefunded(uint256 indexed id);
    event EscrowResolved(uint256 indexed id, address winner);

    struct EscrowDetails {
        address payer;
        address payee;
        uint256 value;
        bytes32 hashlock;
        uint64 timelock;
        uint8 status; // 0:Created, 1:Released, 2:Refunded, 3:Resolved
    }

    function createEscrow(address payee, bytes32 hashlock, uint64 timelock) external payable returns (uint256 id);
    function release(uint256 id, bytes calldata preimage) external;
    function refund(uint256 id) external;
    function resolve(uint256 id, bool toPayee) external;
    function getEscrow(uint256 id) external view returns (EscrowDetails memory);
}
