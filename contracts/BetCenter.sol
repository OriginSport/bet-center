pragma solidity ^0.4.18;

import './OracBet.sol';
import './Bet.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract BetCenter is Ownable {

  mapping(bytes32 => OracBet[]) public oracBets;
  mapping(bytes32 => Bet[]) public bets;

  event LogCreateBet(address indexed dealerAddr, address betAddr, bytes32 indexed category, uint indexed startTime);

  function() payable public {}

  function createOracBet(bytes32 category, bytes32 gameId, uint minimumBet, 
                  uint spread, uint leftOdds, uint middleOdds, uint rightOdds, uint flag,
                  uint startTime, uint duration) payable public {
    OracBet oracBet = (new OracBet).value(msg.value)(msg.sender, category, gameId, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , flag, startTime, duration);
    oracBets[category].push(oracBet);
    LogCreateBet(msg.sender, oracBet, category, startTime);
  }

  function createBet(bytes32 category, bytes32 gameId, uint minimumBet, 
                  uint8 spread, uint16 leftOdds, uint16 middleOdds, uint16 rightOdds, uint8 flag,
                  uint startTime, uint8 confirmations) payable public {
    Bet bet = (new Bet).value(msg.value)(msg.sender, category, gameId, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , flag, startTime, confirmations, owner);
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

  /**
   * @dev fetch oraclize bets use category
   * @param category Indicate the sports events type
   */
  function getOracBetsByCategory(bytes32 category) view public returns (OracBet[]) {
    return oracBets[category];
  }
}

