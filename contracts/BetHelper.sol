pragma solidity ^0.4.24;

import './BetBase.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract BetHelper is Ownable {

    event LogCreateBet(uint indexed startTime, uint indexed spreadTag, bytes32 indexed category, uint deposit, address bet);

    function() payable public {}

    function createBet(bytes32 category, uint8 spread, uint8 flag, uint16 leftOdds, uint16 middleOdds, uint16 rightOdds, uint minimumBet, uint startTime)
    payable public {
        BetBase bet = (new BetBase).value(msg.value)(msg.sender, category, spread, flag, leftOdds, middleOdds, rightOdds, minimumBet, startTime, owner);
        spread = spread == 0 ? 0 : 1;
        emit LogCreateBet(startTime, spread, category, msg.value, bet);
    }
}

