pragma solidity 0.4.19;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './utils/DataCenterBridge.sol';


contract Bet is Ownable, DataCenterBridge {
  using SafeMath for uint;

  event LogDistributeReward(address addr, uint reward);
  event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, uint leftPts, uint rightPts);
  event LogParticipant(address addr, uint choice, uint betAmount);

  /** 
   * @desc
   * gameId: is a fixed string just like "0021701030"
   *   the full gameId encode(include football, basketball, esports..) will publish on github
   * leftOdds: need divide 100, if odds is 216 means 2.16
   * middleOdds: need divide 100, if odds is 175 means 1.75
   * rightOdds: need divide 100, if odds is 250 means 2.50
   * spread: need sub 0.5, if spread is 1 means 0.5, 0 means no spread
   * flag: indicate which team get spread, 1 means leftTeam, 3 means rightTeam
   */
  bytes32 public category;
  bytes32 public gameId;
  uint public minimumBet;
  uint public spread;
  uint public flag;
  uint public leftOdds;
  uint public middleOdds;
  uint public rightOdds;

  struct Player {
    uint betAmount;
    uint choice;
  }

  /**
   * @desc
   * winChoice: Indicate the winner choice of this betting
   *   1 means leftTeam win, 3 means rightTeam win, 2 means draw(leftTeam is not always equivalent to the home team)
   * flag: Indicate which team take spread
   *   1 means leftTeam, 3 means rightTeam
   */
  address public dealer;
  uint16 public leftPts;
  uint16 public rightPts;
  uint8 public confirmations = 0;
  uint public neededConfirmations = 1;
  uint public deposit = 0;
  uint public totalBetAmount = 0;
  uint public leftAmount;
  uint public middleAmount;
  uint public rightAmount;
  uint public numberOfBet;
  uint public winChoice;
  uint public startTime;

  address [] players;
  mapping(address => Player) public playerInfo;

  function() payable public {}

  function Bet(address _dealer, bytes32 _category, bytes32 _gameId, uint _minimumBet, 
                  uint _spread, uint _leftOdds, uint _middleOdds, uint _rightOdds, uint _flag,
                  uint _startTime, uint _neededConfirmations, address _owner) payable public {
    require(_flag == 1 || _flag == 3);
    require(_startTime > now);
    require(msg.value >= 0.1 ether);
    require(_neededConfirmations >= neededConfirmations);
    dealer = _dealer;
    deposit = msg.value;
    flag = _flag;
    category = _category;
    gameId = _gameId;
    minimumBet = _minimumBet;
    spread = _spread;
    leftOdds = _leftOdds;
    middleOdds = _middleOdds;
    rightOdds = _rightOdds;
    startTime = _startTime;
    neededConfirmations = _neededConfirmations;
    owner = _owner;
  }

  /**
   * @dev calculate the gas whichdistribute rewards will cost
   * set default gasPrice is 5000000000
   */
  function getRefundTxFee() public view returns (uint) {
    return numberOfBet.mul(5000000000 * 21000);
  }

  /**
   * @dev find a player has participanted or not
   * @param player the address of the participant
   */
  function checkPlayerExists(address player) public view returns (bool) {
    if (playerInfo[player].choice == 0) {
      return false;
    }
    return true;
  }

  /**
   * @dev to check the dealer is solvent or not
   * @param choice indicate which team user choose
   * @param amount indicate how many ether user bet
   */
  function isSolvent(uint choice, uint amount) internal view returns (bool) {
    uint needAmount;
    if (choice == 1) {
      needAmount = leftOdds.mul(leftAmount.add(amount)).div(100);
    } else if (choice == 2) {
      needAmount = middleOdds.mul(middleAmount.add(amount)).div(100);
    } else {
      needAmount = rightOdds.mul(rightAmount.add(amount)).div(100);
    }

    if (needAmount.add(getRefundTxFee()) > totalBetAmount.add(amount).add(deposit)) {
      return false;
    } else {
      return true;
    }
  }

  /**
   * @dev update this bet some state
   * @param choice indicate which team user choose
   * @param amount indicate how many ether user bet
   */
  function updateAmountOfEachChoice(uint choice, uint amount) internal {
    if (choice == 1) {
      leftAmount == leftAmount.add(amount);
    } else if (choice == 2) {
      middleAmount = middleAmount.add(amount);
    } else {
      rightAmount = rightAmount.add(amount);
    }
  }

  /**
   * @dev place a bet with his/her choice
   * @param choice indicate which team user choose
   */
  function placeBet(uint choice) public payable {
    require(now < startTime);
    require(choice == 1 ||  choice == 2 || choice == 3);
    require(msg.value >= minimumBet);
    require(!checkPlayerExists(msg.sender));

    if (!isSolvent(choice, msg.value)) {
      revert();
    }

    playerInfo[msg.sender].betAmount = msg.value;
    playerInfo[msg.sender].choice = choice;

    totalBetAmount = totalBetAmount.add(msg.value);
    numberOfBet = numberOfBet.add(1);
    updateAmountOfEachChoice(choice, msg.value);
    LogParticipant(msg.sender, choice, msg.value);
  }

  /**
   * @dev in order to let more people participant, dealer can recharge
   */
  function rechargeDeposit() public payable {
    require(msg.value >= minimumBet);
    deposit = deposit.add(msg.value);
  }

  function getWinChoice(uint _leftPts, uint _rightPts) public view returns (uint) {
    uint _winChoice;
    if (spread == 0) {
      if (_leftPts > _rightPts) {
        _winChoice = 1;
      } else if (_leftPts == _rightPts) {
        _winChoice = 2;
      } else {
        _winChoice = 3;
      }
    } else {
      if (flag == 1) {
        if (_leftPts + spread > _rightPts) {
          _winChoice = 1;
        } else {
          _winChoice = 3;
        }
      } else {
        if (_rightPts + spread > _leftPts) {
          _winChoice = 3;
        } else {
          _winChoice = 1;
        }
      }
    }
    return _winChoice;
  }

  /**
   * @dev manualCloseBet could only be called by owner
   */
  function manualCloseBet(uint16 _leftPts, uint16 _rightPts) onlyOwner external {
    leftPts = _leftPts;
    rightPts = _rightPts;

    LogGameResult(category, gameId, leftPts, rightPts);

    winChoice = getWinChoice(leftPts, rightPts);

    require(winChoice == 1 || winChoice == 2 || winChoice == 3);

    if (winChoice == 1) {
      distributeReward(leftOdds);
    } else if (winChoice == 2) {
      distributeReward(middleOdds);
    } else {
      distributeReward(rightOdds);
    }
  }

  /**
   * @dev closeBet could be called by everyone, but owner/dealer should to this.
   */
  function closeBet() external {
    (leftPts, rightPts, confirmations) = dataCenterGetResult(gameId);

    require(confirmations >= neededConfirmations);

    LogGameResult(category, gameId, leftPts, rightPts);

    winChoice = getWinChoice(leftPts, rightPts);

    if (winChoice == 1) {
      distributeReward(leftOdds);
    } else if (winChoice == 2) {
      distributeReward(middleOdds);
    } else {
      distributeReward(rightOdds);
    }
  }

  /**
   * @dev if there are some reasons lead game postpone or cancel
   *      the bet will also cancel and refund every bet
   */
  function refund() public {
    for(uint i = 0; i < players.length; i++) {
      address playerAddress = players[i];
      playerAddress.transfer(playerInfo[playerAddress].betAmount);
    }
  }

  /**
   * @dev distribute ether to every winner as they choosed odds
   */
  function distributeReward(uint winOdds) internal {
    for(uint i = 0; i < players.length; i++) {
      address playerAddress = players[i];
      if(playerInfo[playerAddress].choice == winChoice) {
        // Distribute ether to winners
        playerAddress.transfer(winOdds * playerInfo[playerAddress].betAmount / 100);
        LogDistributeReward(playerAddress, winOdds * playerInfo[playerAddress].betAmount / 100);
      }
    }
  }
}
