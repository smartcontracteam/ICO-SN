pragma solidity ^0.4.11;

import './Ownable.sol';

 /// @title Contactable contract - basic version of a contactable contract
 /// @author dev@smartcontracteam.com
contract Contactable is Ownable {
     string public contactInformation;

     function setContactInformation(string info) onlyOwner{
         contactInformation = info;
     }
}
