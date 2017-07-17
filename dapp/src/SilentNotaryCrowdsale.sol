pragma solidity ^0.4.11;

import '/src/common/SafeMath.sol';
import '/src/common/lifecycle/Haltable.sol';
import '/src/SilentNotaryToken.sol';

/*
This code is in the testing stage and may contain certain bugs. 
These bugs will be identified and eliminated by the team at the testing stage before the ICO.
Please treat with understanding. If you become aware of a problem, please let us know by e-mail: service@silentnotary.com.
If the problem is critical and security related, we will credit you with the reward from the team's share in the tokens 
at the end of the ICO (as officially announced at bitcointalk.org).
Thanks for the help.
*/


 /// @title SilentNotary  сrowdsale contract
 /// @author dev@smartcontracteam.com
contract SilentNotaryCrowdsale is Haltable, SafeMath {

  //// The token we are selling
  SilentNotaryToken public token;

  /// Multisig wallet
  address public multisigWallet;

  /// The UNIX timestamp start date of the crowdsale
  uint public startsAt;

  ///  the UNIX timestamp end date of the crowdsale
  uint public endsAt;

  /// the number of tokens already sold through this contract
  uint public tokensSold = 0;

  ///  How many wei of funding we have raised
  uint public weiRaised = 0;

  ///  How many distinct addresses have invested
  uint public investorCount = 0;

  ///  How much wei we have returned back to the contract after a failed crowdfund.
  uint public loadedRefund = 0;

  ///  How much wei we have given back to investors.
  uint public weiRefunded = 0;

  ///  Has this crowdsale been finalized
  bool public finalized;

  ///  How much ETH each address has invested to this crowdsale
  mapping (address => uint256) public investedAmountOf;

  ///  How much tokens this crowdsale has credited for each investor address
  mapping (address => uint256) public tokenAmountOf;

  /// if the funding goal is not reached, investors may withdraw their funds
  uint public constant FUNDING_GOAL = 20 ether;

  /// topup team wallet on 5(testing) Eth after that will topup both - team and multisig wallet by 32% and 68%
  uint constant MULTISIG_WALLET_GOAL = 5 ether;

  /// Minimum order quantity 0.1 ether
  uint public constant MIN_INVESTEMENT = 100 finney;

  /// ICO start token price
  uint public constant MIN_PRICE = 100 finney;

  /// Maximum token price, if reached ICO will stop
  uint public constant MAX_PRICE = 200 finney;

  /// How much ICO tokens to sold
  uint public constant INVESTOR_TOKENS  = 90000;

  /// How much ICO tokens will get team
  uint public constant TEAM_TOKENS = 10000;

  int priceCalculatingRatio = -1;

  uint public tokenPrice = MIN_PRICE;

   /// State machine
   /// Preparing: All contract initialization calls and variables have not been set yet
   /// Funding: Active crowdsale
   /// Success: Minimum funding goal reached
   /// Failure: Minimum funding goal not reached before ending time
   /// Finalized: The finalized has been called and succesfully executed
   /// Refunding: Refunds are loaded on the contract for reclaim
  enum State{Unknown, Preparing, Funding, Success, Failure, Finalized, Refunding}

  /// A new investment was made
  event Invested(address investor, uint weiAmount, uint tokenAmount);

  /// Refund was processed for a contributor
  event Refund(address investor, uint weiAmount);

  /// Crowdsale end time has been changed
  event EndsAtChanged(uint endsAt);

  /// New price was calculated
  event PriceChanged(uint oldValue, uint newValue);

  /// Modified allowing execution only if the crowdsale is currently runnin
  modifier inState(State state) {
    if(getState() != state) throw;
    _;
  }

  /// @dev Constructor
  /// @param _token SNTR token address
  /// @param _multisigWallet  multisig wallet address
  /// @param _start  ICO start time
  /// @param _end  ICO end time
  function Crowdsale(address _token, address _multisigWallet, uint _start, uint _end) {
    owner = msg.sender;
    token = SilentNotaryToken(_token);
    multisigWallet = _multisigWallet;

    if(multisigWallet == 0) {
        throw;
    }

    if(_start == 0) {
        throw;
    }

    startsAt = _start;

    if(_end == 0) {
        throw;
    }

    endsAt = _end;

    // Don't mess the dates
    if(startsAt >= endsAt) {
        throw;
    }
  }

  /// @dev Don't expect to just send in money and get tokens.
  function() payable {
    throw;
  }

   /// @dev Make an investment.
   /// @param receiver The Ethereum address who receives the tokens
  function investInternal(address receiver) stopInEmergency private {
    // Determine if it's a good time to accept investment from this participant
    if(getState() == State.Funding) {
      // Retail participants can only come in when the crowdsale is running
      // pass
    } else {
      // Unwanted state
      throw;
    }

    uint weiAmount = msg.value;
    if(weiAmount < MIN_INVESTEMENT)
      throw;

    uint tokenAmount;
    if(tokenPrice == uint(MIN_PRICE)) {
        tokenAmount = safeDiv(weiAmount, MIN_PRICE);
    }
    else {
      tokenAmount = safeDiv(weiAmount, tokenPrice);
    }

    if(tokenAmount == 0) {
      // Dust transaction
      throw;
    }

    var price = calculatePrice(tokenAmount);
    PriceChanged(tokenPrice, price);
    tokenPrice = price;

    if(investedAmountOf[receiver] == 0) {
       // A new investor
       investorCount++;
    }
    // Update investor
    investedAmountOf[receiver] = safeAdd(investedAmountOf[receiver], weiAmount);
    tokenAmountOf[receiver] = safeAdd(tokenAmountOf[receiver], tokenAmount);
    // Update totals
    weiRaised = safeAdd(weiRaised, weiAmount);
    tokensSold = safeAdd(tokensSold, tokenAmount);

    // Check that we did not bust the cap
    if(isBreakingCap(weiAmount, tokenAmount, weiRaised, tokensSold)) {
      throw;
    }

    assignTokens(receiver, tokenAmount);

    if(weiRaised <= MULTISIG_WALLET_GOAL) {
      if(!multisigWallet.send(weiAmount)) throw;
    }
    else {
      int remain = int(weiAmount - weiRaised - MULTISIG_WALLET_GOAL);

      if(remain > 0) {
        if(!multisigWallet.send(uint(remain))) throw;
        weiAmount = weiAmount - uint(remain);
      }

      var distributedAmount = safeDiv(safeMul(weiAmount, 32), 100);
      if(!owner.send(distributedAmount)) throw;
      if(!multisigWallet.send(safeSub(weiAmount, distributedAmount))) throw;

    }
    // Tell us invest was success
    Invested(receiver, weiAmount, tokenAmount);
  }

   /// @dev Allow anonymous contributions to this crowdsale.
   /// @param receiver The Ethereum address who receives the tokens
  function invest(address receiver) public payable {
    investInternal(receiver);
  }

   /// @dev Pay for funding, get invested tokens back in the sender address.
  function buy() public payable {
    invest(msg.sender);
  }

  /// @dev Finalize a succcesful crowdsale. The owner can triggre a call the contract that provides post-crowdsale actions, like releasing the tokens.
  function finalize() public inState(State.Success) onlyOwner stopInEmergency {
    // Already finalized
    if(finalized) {
      throw;
    }

    finalizeCrowdsale();
    finalized = true;
  }

  /// @dev Finalize a succcesful crowdsale.
  function finalizeCrowdsale() internal {
    assignTokens(owner, safeAdd(safeSub(INVESTOR_TOKENS, tokensSold), TEAM_TOKENS));
    token.releaseTokenTransfer();
  }

  /// @dev Allow crowdsale owner to close early or extend the crowdsale.
  /// @param time crowdsale close time
  function setEndsAt(uint time) onlyOwner {
    if(now > time) {
      throw; // Don't change past
    }

    endsAt = time;
    EndsAtChanged(endsAt);
  }

   /// @dev  Allow to change the team multisig address in the case of emergency.
   /// @param _multisigWallet crowdsale close time
  function setMultisig(address _multisigWallet) public onlyOwner {
    multisigWallet = _multisigWallet;
  }

   /// @dev  Allow load refunds back on the contract for the refunding. The team can transfer the funds back on the smart contract in the case the minimum goal was not reached.
  function loadRefund() public payable inState(State.Failure) {
    if(msg.value == 0) throw;
    loadedRefund = safeAdd(loadedRefund, msg.value);
  }

  /// @dev  Investors can claim refund.
  function refund() public inState(State.Refunding) {
    uint256 weiValue = investedAmountOf[msg.sender];
    if (weiValue == 0) throw;
    investedAmountOf[msg.sender] = 0;
    weiRefunded = safeAdd(weiRefunded, weiValue);
    Refund(msg.sender, weiValue);
    if (!msg.sender.send(weiValue)) throw;
  }

  /// @dev Minimum goal was reached
  /// @return true if the crowdsale has raised enough money to be a succes
  function isMinimumGoalReached() public constant returns (bool reached) {
    return weiRaised >= FUNDING_GOAL;
  }

   /// @dev Crowdfund state machine management.
   /// @return State current state
  function getState() public constant returns (State) {
    if(finalized) return State.Finalized;
    else if (address(token) == 0) return State.Preparing;
    else if (address(multisigWallet) == 0) return State.Preparing;
	  else if (block.timestamp < startsAt) return State.Preparing;
    else if (block.timestamp <= endsAt && !isCrowdsaleFull()) return State.Funding;
    else if (isMinimumGoalReached()) return State.Success;
    else if (!isMinimumGoalReached() && weiRaised > 0 && loadedRefund >= weiRaised) return State.Refunding;
    else return State.Failure;
  }

  /// @dev Calculating price, it is not linear function
  /// @param tokenAmount tokens to buy
  /// @return price in wei
  function calculatePrice(uint tokenAmount) internal returns (uint price) {
    if(tokenAmount == 0)
      throw;

    uint multiplier = 10**token.decimals();
    priceCalculatingRatio = priceCalculatingRatio * int(multiplier + tokenAmount * multiplier) / int(INVESTOR_TOKENS);
    price = (uint(priceCalculatingRatio) * (MAX_PRICE - MIN_PRICE)  + MAX_PRICE * multiplier) / multiplier;
    return price;
  }

   /// @dev Called from invest() to confirm if the curret investment does not break our cap rule.
   /// @param weiAmount tokens to buy
   /// @param tokenAmount tokens to buy
   /// @param weiRaisedTotal tokens to buy
   /// @param tokensSoldTotal tokens to buy
   /// @return limit result
   function isBreakingCap(uint weiAmount, uint tokenAmount, uint weiRaisedTotal, uint tokensSoldTotal) constant returns (bool limitBroken) {
     return tokensSoldTotal > INVESTOR_TOKENS;
   }

   /// @dev Check crowdsale limit
   /// @return limit reached result
   function isCrowdsaleFull() public constant returns (bool) {
     return false;
   }

    /// @dev Dynamically create tokens and assign them to the investor.
    /// @param receiver address
    /// @param tokenAmount tokens amount
   function assignTokens(address receiver, uint tokenAmount) private {
     token.mint(receiver, tokenAmount);
   }
}
