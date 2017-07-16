pragma solidity ^0.4.11;

import '/src/common/lifecycle/Killable.sol';
import '/src/common/token/ERC20.sol';
import '/src/common/SafeMath.sol';
import '/src/TokenHolders.sol';

/*
This code is in the testing stage and may contain certain bugs. 
These bugs will be identified and eliminated by the team at the testing stage before the ICO.
Please treat with understanding. If you become aware of a problem, please let us know by e-mail: service@silentnotary.com.
If the problem is critical and security related, we will credit you with the reward from the team's share in the tokens 
at the end of the ICO (as officially announced at bitcointalk.org).
Thanks for the help.
*/

 /// @title SilentNotaryToken contract - standard ERC20 token with Short Hand Attack and approve() race condition mitigation.
 /// @author dev@smartcontracteam.com
contract SilentNotaryToken is SafeMath, TokenHolders, ERC20, Killable {
  string public name = "Silent Notary Token";
  string public symbol = "SNTR";
  uint public decimals = 8;

  /// Minimum amount for buyout in wei
  uint buyOutAmount;
  /// Buyout price in wei
  uint buyOutPrice;

  /// contract that is allowed to create new tokens and allows unlift the transfer limits on this token
  address public crowdsaleAgent;
  /// A crowdsale contract can release us to the wild if ICO success. If false we are are in transfer lock up period.
  bool public released = false;
  /// approve() allowances
  mapping (address => mapping (address => uint)) allowed;

  /// @dev Limit token transfer until the crowdsale is over.
  modifier canTransfer() {
    if(!released) {
        if(msg.sender != crowdsaleAgent) {
            throw;
        }
    }
    _;
  }

  /// @dev The function can be called only before or after the tokens have been releasesd
  /// @param _released token transfer and mint state
  modifier inReleaseState(bool _released) {
    if(_released != released) {
        throw;
    }
    _;
  }

  /// @dev The function can be called only by release agent.
  modifier onlyCrowdsaleAgent() {
    if(msg.sender != crowdsaleAgent) {
        throw;
    }
    _;
  }

  /// @dev Fix for the ERC20 short address attack http://vessenes.com/the-erc20-short-address-attack-explained/
  /// @param size payload size
  modifier onlyPayloadSize(uint size) {
     if(msg.data.length < size + 4) {
       throw;
     }
     _;
  }

  /// @dev Make sure we are not done yet.
  modifier canMint() {
     if(released) throw;
     _;
   }

  /// Tokens burn event
  event Burned(address indexed burner, address indexed holder, uint burnedAmount);
  /// Tokens buyout event
  event Pay(address indexed to, uint value);
  /// Wei deposit event
  event Deposit(address indexed from, uint value);

  /// @dev Constructor
  /// @param _buyOutPrice Buyout price
  /// @param _buyOutAmount  Buyout limit
  function SilentNotaryToken(uint _buyOutPrice, uint _buyOutAmount) {
    owner = msg.sender;
    buyOutPrice = _buyOutPrice;
    buyOutAmount = _buyOutAmount;
  }

  /// Fallback method will buyout tokens
  function() payable {
    buyout();
  }
  /// @dev Create new tokens and allocate them to an address. Only callably by a crowdsale contract
  /// @param receiver Address of receiver
  /// @param amount  Number of tokens to issue.
  function mint(address receiver, uint amount) onlyCrowdsaleAgent canMint public {
      totalSupply = safeAdd(totalSupply, amount);
      addOrUpdate(receiver, safeAdd(balances.data[receiver].value, amount));
      Transfer(0, receiver, amount);
  }
  /// @dev Set minimum limit for buyout
  /// @param _buyOutAmount min buyout amount
  function setBuyoutMinAmount(uint _buyOutAmount) onlyOwner public {
    buyOutAmount = _buyOutAmount;
  }
  /// @dev Set the contract that can call release and make the token transferable.
  /// @param _crowdsaleAgent crowdsale contract address
  function setCrowdsaleAgent(address _crowdsaleAgent) onlyOwner inReleaseState(false) public {
    crowdsaleAgent = _crowdsaleAgent;
  }
  /// @dev One way function to release the tokens to the wild. Can be called only from the release agent that is the final ICO contract. It is only called if the crowdsale has been success (first milestone reached).
  function releaseTokenTransfer() public onlyCrowdsaleAgent {
    released = true;
  }
  /// @dev Tranfer tokens to address
  /// @param _to dest address
  /// @param _value tokens amount
  /// @return transfer result
  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) canTransfer returns (bool success) {
    addOrUpdate(msg.sender, safeSub(balances.data[msg.sender].value, _value));
    addOrUpdate(_to, safeAdd(balances.data[_to].value, _value));
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /// @dev Tranfer tokens from one address to other
  /// @param _from source address
  /// @param _to dest address
  /// @param _value tokens amount
  /// @return transfer result
  function transferFrom(address _from, address _to, uint _value) canTransfer returns (bool success) {
    uint _allowance = allowed[_from][msg.sender];
    addOrUpdate(_to, safeAdd(balances.data[_to].value, _value));
    addOrUpdate(_from, safeSub(balances.data[_from].value, _value));
    allowed[_from][msg.sender] = safeSub(_allowance, _value);
    Transfer(_from, _to, _value);
    return true;
  }
  /// @dev Tokens balance
  /// @param _owner holder address
  /// @return balance amount
  function balanceOf(address _owner) constant returns (uint balance) {
    return balances.data[_owner].value;
  }

  /// @dev Approve transfer
  /// @param _spender holder address
  /// @param _value tokens amount
  /// @return result
  function approve(address _spender, uint _value) returns (bool success) {
    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) throw;

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /// @dev Token allowance
  /// @param _owner holder address
  /// @param _spender spender address
  /// @return remain amount
  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

  /// @dev Internal burn
  /// @param _holder holder address
  /// @param _amount burn amount
  function burn(address _holder, uint _amount) internal  {
      balances.data[_holder].value = safeSub(balances.data[_holder].value, _amount);
      totalSupply = safeSub(totalSupply, _amount);
      Burned(msg.sender, _holder, _amount);
  }

  /// @dev Internal buyout method
  function buyout() internal  {
    Deposit(msg.sender, msg.value);

    uint totalSupplyAmount = totalSupply;
    uint payoutBalance = safeAdd(this.balance, msg.value);
    if(payoutBalance == 0)
       return;

    if(safeMul(totalSupplyAmount, buyOutPrice) <= payoutBalance)
       buyOutAmount = 0;

    if(payoutBalance < buyOutAmount)
        return;

    for (var i = iterateStart(); iterateValid(i); i = iterateNext(i)) {
      var current = iterateGet(i);
      if(balances.data[current.key].value == 0) {
          continue;
      }

      uint multiplier = 10 ** decimals;
      uint holderTokenPortion =  safeDiv(safeMul(balances.data[current.key].value, multiplier), totalSupplyAmount);
      uint holderWeiPortion  = safeDiv(safeMul(holderTokenPortion, payoutBalance), multiplier);

      if(holderWeiPortion < buyOutPrice)
          continue;

      uint holderBuyoutTokens =  safeDiv(holderWeiPortion, buyOutPrice);
      burn(current.key, holderBuyoutTokens);
      current.key.transfer(holderWeiPortion);
      Pay(current.key, holderWeiPortion);
    }
  }
}
