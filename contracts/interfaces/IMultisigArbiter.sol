// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IMultisigArbiter {
    error MultisigArbiter__NotAnArbiter(address caller);
    error MultisigArbiter__AlreadyConfirmed(uint256 escrowId, bool toPayee, address confirmer);
    error MultisigArbiter__ResolutionAlreadyExecuted(uint256 escrowId, bool toPayee);
    error MultisigArbiter__ResolutionDoesNotExist(uint256 escrowId, bool toPayee);
    error MultisigArbiter__NotEnoughConfirmations(
        uint256 escrowId, bool toPayee, uint256 confirmations, uint256 required
    );
    error MultisigArbiter__InvalidArbiterList();
    error MultisigArbiter__InvalidRequiredConfirmations(uint256 required, uint256 arbiters);
    error MultisigArbiter__InvalidArbiterAddress();
    error MultisigArbiter__DuplicateArbiter(address duplicateAddress);
    error MultisigArbiter__ResolutionAlreadyProposed(uint256 escrowId, bool toPayee);
    error MultisigArbiter__EscrowCallFailed(uint256 escrowId, bool toPayee);
    error MultisigArbiter__NotOwner(address caller);
    error MultisigArbiter__EscrowContractAlreadySet(address currentAddress);
    error MultisigArbiter__InvalidOwnerAddress(address owner);

    event ResolutionProposed(uint256 indexed escrowId, bool toPayee, address indexed proposer);
    event ResolutionConfirmed(uint256 indexed escrowId, bool toPayee, address indexed confirmer);
    event ResolutionExecuted(uint256 indexed escrowId, bool toPayee);

    function proposeResolution(uint256 _escrowId, bool _toPayee) external;
    function confirmResolution(uint256 _escrowId, bool _toPayee) external;
    function executeResolution(uint256 _escrowId, bool _toPayee) external;
    function isResolutionApproved(uint256 _escrowId, bool _toPayee) external view returns (bool);
}
