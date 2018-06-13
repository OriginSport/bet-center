pragma solidity ^0.4.19;

import './Bet.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract BetCenter is Ownable {

  mapping(bytes32 => Bet[]) public bets;
  mapping(bytes32 => bytes32[]) public gameIds;

  event LogCreateBet(address indexed dealerAddr, address betAddr, bytes32 indexed category, uint indexed startTime);

  function() payable public {}

  function createBet(bytes32 category, bytes32 gameId, uint minimumBet, 
                  uint8 spread, uint16 leftOdds, uint16 middleOdds, uint16 rightOdds, uint8 flag,
                  uint startTime, uint8 confirmations) payable public {
    Bet bet = (new Bet).value(msg.value)(msg.sender, category, gameId, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , flag, startTime, confirmations, owner);
    bets[category].push(bet);
    gameIds[category].push(gameId);
    LogCreateBet(msg.sender, bet, category, startTime);
  }

  /**
   * @dev fetch bets use category
   * @param category Indicate the sports events type
   */
  function getBetsByCategory(bytes32 category) view public returns (Bet[]) {
    return bets[category];
  }

  function getGameIdsByCategory(bytes32 category) view public returns (bytes32 []) {
    return gameIds[category];
  }

}

