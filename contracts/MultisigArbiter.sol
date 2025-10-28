// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import { IMultisigArbiter } from "./interface/IMultisigArbiter.sol";

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
  error MultisigArbiter__NotEnoughConfirmations(uint256 escrowId, bool toPayee, uint256 confirmations, uint256 required);
  error MultisigArbiter__InvalidArbiterList();
  error MultisigArbiter__InvalidRequiredConfirmations(uint256 required, uint256 arbiters);

  modifier onlyArbiter() {
    if (!s_isArbiter[msg.sender]) {
      revert MultisigArbiter__NotAnArbiter(msg.sender);
    }
  }

  constructor(address[] memory _arbiters, uint256 _requiredConfirmations, address)
}