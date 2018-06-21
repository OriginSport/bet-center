pragma solidity ^0.4.19;

import './Bet.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract BetCenter is Ownable {

  event LogCreateBet(uint indexed startTime, uint indexed spreadTag, bytes32 indexed category, uint deposit, address bet, bytes32 gameId);

  function() payable public {}

  function createBet(bytes32 category, bytes32 gameId, uint minimumBet, 
                  uint8 spread, uint16 leftOdds, uint16 middleOdds, uint16 rightOdds, uint8 flag,
                  uint startTime, uint8 confirmations) payable public {
    Bet bet = (new Bet).value(msg.value)(msg.sender, category, gameId, minimumBet, 
                  spread, leftOdds, middleOdds, rightOdds , flag, startTime, confirmations, owner);
    if (spread == 0) {
      LogCreateBet(startTime, 0, category, msg.value, bet, gameId);
    } else {
      LogCreateBet(startTime, 1, category, msg.value, bet, gameId);
    }
  }
}

