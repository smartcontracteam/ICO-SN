pragma solidity ^0.4.13;

import "../ownership/Ownable.sol";

 /// @title Pausable contract - abstract contract that allows children to implement an emergency stop mechanism.
 /// @author dev@smartcontracteam.com
contract Pausable is Ownable {
  bool public stopped;

  modifier stopInEmergency {
    if (!stopped) {
      _;
    }
  }

  modifier onlyInEmergency {
    if (stopped) {
      _;
    }
  }

  /// called by the owner on emergency, triggers stopped state
  function emergencyStop() external onlyOwner {
    stopped = true;
  }

  /// called by the owner on end of emergency, returns to normal state
  function release() external onlyOwner onlyInEmergency {
    stopped = false;
  }
}
