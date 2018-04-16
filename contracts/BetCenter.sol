pragma solidity ^0.4.18;

import './Bet.sol';

contract BetCenter {

  mapping(bytes32 => Bet[]) public bets;

  event LogCreateBet(address indexed dealerAddr, address betAddr, bytes32 category);

  function() payable public {}

  function createBet(bytes32 category, bytes32 gameId, uint deposit, uint minimumBet, 
                  uint spread, uint leftOdds, uint middleOdds, uint rightOdds, uint _flag,
                  uint startTime, uint duration) payable public {
    Bet bet = new Bet(category, gameId, deposit, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , _flag, startTime, duration);
    bets[category].push(bet);
    LogCreateBet(msg.sender, bet, category);
  }

  function getBetsByCategory(bytes32 category) constant public returns (Bet[]) {
    return bets[category];
  }
}

