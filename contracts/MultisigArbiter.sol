// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IMultisigArbiter } from "./interfaces/IMultisigArbiter.sol";

contract MultisigArbiter is IMultisigArbiter {
    address public immutable i_escrowContract;
    uint256 public immutable i_requiredConfirmations;
    address[] public s_arbiters;
    mapping(address => bool) private s_isArbiter;

    struct Resolution {
        bool exists;
        bool executed;
        uint256 confirmationCount;
        mapping(address => bool) hasConfirmed;
    }

    mapping(uint256 => mapping(bool => Resolution)) private s_resolutions;

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

    modifier onlyArbiter() {
        if (!s_isArbiter[msg.sender]) {
            revert MultisigArbiter__NotAnArbiter(msg.sender);
        }
        _;
    }

    constructor(address[] memory arbiters, uint256 requiredConfirmations, address escrowContract) {
        if (arbiters.length == 0) {
            revert MultisigArbiter__InvalidArbiterList();
        }
        if (requiredConfirmations == 0 || requiredConfirmations > arbiters.length) {
            revert MultisigArbiter__InvalidRequiredConfirmations(requiredConfirmations, arbiters.length);
        }

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
        i_escrowContract = escrowContract;
    }

    function proposeResolution(uint256 escrowId, bool toPayee) external override onlyArbiter {
      Resolution storage resolution = s_resolutions[_escrowId][_toPayee];  
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

    
}
