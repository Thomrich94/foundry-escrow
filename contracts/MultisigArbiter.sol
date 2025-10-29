// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IMultisigArbiter } from "./interfaces/IMultisigArbiter.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";

contract MultisigArbiter is IMultisigArbiter {
    uint256 public immutable i_requiredConfirmations;
    address public immutable i_owner;
    address[] public s_arbiters;
    address public s_escrowContract;
    mapping(address => bool) private s_isArbiter;

    struct Resolution {
        bool exists;
        bool executed;
        uint256 confirmationCount;
        mapping(address => bool) hasConfirmed;
    }

    mapping(uint256 => mapping(bool => Resolution)) private s_resolutions;

    modifier onlyArbiter() {
        if (!s_isArbiter[msg.sender]) {
            revert MultisigArbiter__NotAnArbiter(msg.sender);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert MultisigArbiter__NotOwner(msg.sender);
        }
        _;
    }

    constructor(address owner, address[] memory arbiters, uint256 requiredConfirmations) {
        if (arbiters.length == 0) {
            revert MultisigArbiter__InvalidArbiterList();
        }
        if (requiredConfirmations == 0 || requiredConfirmations > arbiters.length) {
            revert MultisigArbiter__InvalidRequiredConfirmations(requiredConfirmations, arbiters.length);
        }
        if (owner == address(0)) {
            revert MultisigArbiter__InvalidOwnerAddress(owner);
        }

        i_owner = owner;

        for (uint256 i = 0; i < arbiters.length; i++) {
            address arbiter = arbiters[i];
            if (arbiter == address(0)) {
                revert MultisigArbiter__InvalidArbiterAddress();
            }
            if (s_isArbiter[arbiter]) {
                revert MultisigArbiter__DuplicateArbiter(arbiter);
            }

            s_isArbiter[arbiter] = true;
            s_arbiters.push(arbiter);
        }
        i_requiredConfirmations = requiredConfirmations;
    }

    function proposeResolution(uint256 escrowId, bool toPayee) external override onlyArbiter {
        Resolution storage resolution = s_resolutions[escrowId][toPayee];
        if (resolution.exists) {
            revert MultisigArbiter__ResolutionAlreadyProposed(escrowId, toPayee);
        }

        resolution.exists = true;
        resolution.hasConfirmed[msg.sender] = true;
        resolution.confirmationCount = 1;

        emit ResolutionProposed(escrowId, toPayee, msg.sender);
        emit ResolutionConfirmed(escrowId, toPayee, msg.sender);
    }

    function confirmResolution(uint256 escrowId, bool toPayee) external override onlyArbiter {
        Resolution storage resolution = s_resolutions[escrowId][toPayee];
        if (!resolution.exists) {
            revert MultisigArbiter__ResolutionDoesNotExist(escrowId, toPayee);
        }
        if (resolution.hasConfirmed[msg.sender]) {
            revert MultisigArbiter__AlreadyConfirmed(escrowId, toPayee, msg.sender);
        }

        resolution.hasConfirmed[msg.sender] = true;
        resolution.confirmationCount++;

        emit ResolutionConfirmed(escrowId, toPayee, msg.sender);
    }

    function executeResolution(uint256 escrowId, bool toPayee) external override onlyArbiter {
        Resolution storage resolution = s_resolutions[escrowId][toPayee];
        if (!resolution.exists) {
            revert MultisigArbiter__ResolutionDoesNotExist(escrowId, toPayee);
        }
        if (resolution.executed) {
            revert MultisigArbiter__ResolutionAlreadyExecuted(escrowId, toPayee);
        }
        if (resolution.confirmationCount < i_requiredConfirmations) {
            revert MultisigArbiter__NotEnoughConfirmations(
                escrowId, toPayee, resolution.confirmationCount, i_requiredConfirmations
            );
        }

        resolution.executed = true;

        try IEscrow(s_escrowContract).resolve(escrowId, toPayee) {
            emit ResolutionExecuted(escrowId, toPayee);
        } catch {
            revert MultisigArbiter__EscrowCallFailed(escrowId, toPayee);
        }

        emit ResolutionExecuted(escrowId, toPayee);
    }

    function isResolutionApproved(uint256 escrowId, bool toPayee) external view override returns (bool) {
        Resolution storage resolution = s_resolutions[escrowId][toPayee];
        return resolution.exists && !resolution.executed && resolution.confirmationCount >= i_requiredConfirmations;
    }

    function setEscrowContract(address escrowContract) external {
        require(msg.sender == i_owner, "Only owner can set the escrow contract");
        require(s_escrowContract == address(0), "Escrow contract already set");
        s_escrowContract = escrowContract;
    }

    function getArbiters() external view returns (address[] memory) {
        return s_arbiters;
    }

    function getResolution(uint256 escrowId, bool toPayee)
        external
        view
        returns (bool exists, bool executed, uint256 confirmationCount)
    {
        Resolution storage resolution = s_resolutions[escrowId][toPayee];
        return (resolution.exists, resolution.executed, resolution.confirmationCount);
    }
}
