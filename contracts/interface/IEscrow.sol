// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IEscrow {
    event EscrowCreated(
        uint256 indexed id,
        address indexed payer,
        address indexed payee,
        uint256 value,
        bytes32 hashlock,
        uint64 timelock
    );
    event Released(uint256 indexed id, bytes preimage);
    event Refunded(uint256 indexed id);
    event Resolved(uint256 indexed id, address winner);

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
