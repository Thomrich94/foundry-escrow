// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IMultisigArbiter {
    event ResolutionProposed(uint256 indexed escrowId, bool toPayee, address indexed proposer);
    event ResolutionConfirmed(uint256 indexed escrowId, bool toPayee, address indexed confirmer);
    event ResolutionExecuted(uint256 indexed escrowId, bool toPayee);

    function proposeResolution(uint256 _escrowId, bool _toPayee) external;
    function confirmResolution(uint256 _escrowId, bool _toPayee) external;
    function executeResolution(uint256 _escrowId, bool _toPayee) external;
    function isResolutionApproved(uint256 _escrowId, bool _toPayee) external view returns (bool);
}