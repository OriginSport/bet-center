pragma solidity ^0.4.18;

import './Bet.sol';

contract BetCenter {

  mapping(bytes32 => Bet[]) public bets;

  event LogCreateBet(address dealerAddr, bytes32 category);

  function() payable public {}

  function createBet(bytes32 category, bytes32 gameId, uint deposit, uint minimumBet, 
                  uint spread, uint awayOdds, uint homeOdds, uint _flag) payable public {
    Bet bet = new Bet(category, gameId, deposit, minimumBet, 
                  spread, awayOdds, homeOdds, _flag);
    bets[category].push(bet);
    LogCreateBet(msg.sender, category);
  }

  function getBetsByCategory(bytes32 category) constant public returns (Bet[]) {
    return bets[category];
  }
}

