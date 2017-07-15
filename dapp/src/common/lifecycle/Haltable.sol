pragma solidity ^0.4.11;

import "/src/common/ownership/Ownable.sol";

/// @title Haltable contract - abstract contract that allows children to implement an emergency stop mechanism.
/// @author dev@smartcontracteam.com
/// Originally envisioned in FirstBlood ICO contract.
contract Haltable is Ownable {
  bool public halted;

  modifier stopInEmergency {
    if (halted) throw;
    _;
  }

  modifier onlyInEmergency {
    if (!halted) throw;
    _;
  }

  /// called by the owner on emergency, triggers stopped state
  function halt() external onlyOwner {
    halted = true;
  }

  /// called by the owner on end of emergency, returns to normal state
  function unhalt() external onlyOwner onlyInEmergency {
    halted = false;
  }
}
