pragma solidity ^0.4.18;

import './Bet.sol';

contract BetCenter {

  mapping(bytes32 => Bet[]) public bets;

  event LogCreateBet(address indexed dealerAddr, address betAddr, bytes32 indexed category, uint indexed startTime);

  function() payable public {}

  function createBet(bytes32 category, bytes32 gameId, uint minimumBet, 
                  uint spread, uint leftOdds, uint middleOdds, uint rightOdds, uint flag,
                  uint startTime, uint duration) payable public {
    Bet bet = (new Bet).value(msg.value)(msg.sender, category, gameId, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , flag, startTime, duration);
    bets[category].push(bet);
    LogCreateBet(msg.sender, bet, category, startTime);
  }

  /**
   * @dev fetch bets use category
   * @param category Indicate the sports events type
   */
  function getBetsByCategory(bytes32 category) view public returns (Bet[]) {
    return bets[category];
  }
}

