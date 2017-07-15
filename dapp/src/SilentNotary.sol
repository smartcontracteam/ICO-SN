pragma solidity ^0.4.11;

import './common/ownership/Ownable.sol';
import './common/token/ERC20.sol';

/// @title SilentNotary contract - store SHA-384 file hash in blockchain
/// @author dev@smartcontracteam.com
contract SilentNotary is Ownable {
	uint public price;
	address public token;

	struct Entry {
		uint blockNumber;
		uint timestamp;
	}

	mapping (bytes32 => Entry) public entryStorage;

	event EntryAdded(bytes32 hash, uint blockNumber, uint timestamp);
	event EntryExistAlready(bytes32 hash, uint timestamp);

	/// Fallback method
	function () {
	  	// If ether is sent to this address, send it back
	  	throw;
	}

	/// @dev Set price in SNTR tokens for storing
	/// @param _price price in SNTR tokens
	function setRegistrationPrice(uint _price) onlyOwner {
		price = _price;
	}

	/// @dev Set SNTR token address
	/// @param _token Address SNTR tokens contract
		function setTokenAddress(address _token) onlyOwner {
		token = _token;
	}

	/// @dev Register file hash in contract, web3 integration
	/// @param hash SHA-384 file hash
	function makeRegistration(bytes32 hash) onlyOwner public {
			makeRegistrationInternal(hash);
	}

	/// @dev Payable registration in SNTR tokens
	/// @param hash SHA-384 file hash
	function makePayableRegistration(bytes32 hash) public {
			address sender = msg.sender;
	    ERC20 token = ERC20(tokenAddress);
	    uint amount = token.allowance(sender, owner);
	    if(amount == 0) throw;
	    if(!token.transferFrom(sender, owner, price)) throw;
			makeRegistrationInternal(hash);
	}

	/// @dev Internal registation method
	/// @param hash SHA-384 file hash
	function makeRegistrationInternal(bytes32 hash) internal {
			uint timestamp = now;
	    // Checks documents isn't already registered
	    if (exist(hash)) {
	        EntryExistAlready(hash, timestamp);
	        throw;
	    }
	    // Registers the proof with the timestamp of the block
	    entryStorage[hash] = Entry(block.number, timestamp);
	    // Triggers a EntryAdded event
	    EntryAdded(hash, block.number, timestamp);
	}

	/// @dev Check hash existance
	/// @param hash SHA-384 file hash
	/// @return Returns true if hash exist
	function exist(bytes32 hash) internal constant returns (bool) {
	    return entryStorage[hash].blockNumber != 0;
	}
}

