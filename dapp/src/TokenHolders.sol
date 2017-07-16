pragma solidity ^0.4.11;

/*
This code is in the testing stage and may contain certain bugs. 
These bugs will be identified and eliminated by the team at the testing stage before the ICO.
Please treat with understanding. If you become aware of a problem, please let us know by e-mail: service@silentnotary.com.
If the problem is critical and security related, we will credit you with the reward from the team's share in the tokens 
at the end of the ICO (as officially announced at bitcointalk.org).
Thanks for the help.
*/

/// @title TokenHolders contract - iterator-based holders container, need for iterate holders
/// @author dev@smartcontracteam.com
contract TokenHolders
{
  struct IndexValue { uint keyIndex; uint value; }
  struct KeyFlag { address key; bool deleted; }
  struct KeyValue { address key; uint value; }

  struct Storage
  {
    mapping(address => IndexValue) data;
    KeyFlag[] keys;
    uint size;
  }

  Storage balances;

  /// @dev Add or update token holders
  /// @param key holder address
  /// @param value token amount
  /// @return replaced result
  function addOrUpdate(address key, uint value) internal returns (bool replaced) {
    uint keyIndex = balances.data[key].keyIndex;
    balances.data[key].value = value;
    if (keyIndex > 0)
      return true;
    else
    {
      keyIndex = balances.keys.length++;
      balances.data[key].keyIndex = keyIndex + 1;
      balances.keys[keyIndex].key = key;
      balances.size++;
      return false;
    }
  }

  /// @dev Remove token holder
  /// @param key holder address
  /// @return result
  function remove(address key) internal returns (bool success) {
    uint keyIndex = balances.data[key].keyIndex;
    if (keyIndex == 0)
      return false;
    delete balances.data[key];
    balances.keys[keyIndex - 1].deleted = true;
    balances.size --;
  }

  /// @dev Check token holder
  /// @param key holder address
  /// @return result
  function contains(address key)  internal returns (bool success) {
    return balances.data[key].keyIndex > 0;
  }
  /// @dev Start iteration
  /// @return holder index
  function iterateStart() internal returns (uint keyIndex) {
    return iterateNext(0);
  }
  /// @dev Check iteration state
  /// @param keyIndex holder address
  /// @return is valid state
  function iterateValid(uint keyIndex) internal returns (bool) {
    return keyIndex < balances.keys.length;
  }

  /// @dev Next iteration
  /// @param keyIndex holder address
  /// @return next holder index
  function iterateNext(uint keyIndex) internal returns (uint r_keyIndex) {
    keyIndex++;
    while (keyIndex < balances.keys.length && balances.keys[keyIndex].deleted)
      keyIndex++;
    return keyIndex;
  }

  /// @dev Get current iterate value
  /// @param keyIndex holder address
  /// @return iterate value
  function iterateGet(uint keyIndex) internal returns (KeyValue r) {
    r.key = balances.keys[keyIndex].key;
    r.value = balances.data[r.key].value;
  }
}
