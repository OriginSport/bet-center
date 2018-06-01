pragma solidity 0.4.19;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './utils/DataCenterBridge.sol';


contract Bet is Ownable, DataCenterBridge {
  using SafeMath for uint;

  event LogDistributeReward(address addr, uint reward, uint index);
  event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, uint leftPts, uint rightPts);
  event LogParticipant(address addr, uint choice, uint betAmount);
  event LogRefund(address addr, uint betAmount);
  event LogBetClosed(bool isRefund, uint timestamp);
  event LogDealerWithdraw(address addr, uint withdrawAmount);

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
  struct BetInfo {
    bytes32 category;
    bytes32 gameId;
    uint8   spread;
    uint8   flag;
    uint16  leftOdds;
    uint16  middleOdds;
    uint16  rightOdds;
    uint    minimumBet;
    uint    startTime;
    uint    deposit;
    address dealer;
  }

  struct Player {
    uint betAmount;
    uint choice;
  }

  /**
   * @desc
   * winChoice: Indicate the winner choice of this betting
   *   1 means leftTeam win, 3 means rightTeam win, 2 means draw(leftTeam is not always equivalent to the home team)
   */
  uint8 public winChoice;
  uint8 public confirmations = 0;
  uint8 public neededConfirmations = 1;
  uint16 public leftPts;
  uint16 public rightPts;
  bool public isBetClosed = false;

  uint public totalBetAmount = 0;
  uint public leftAmount;
  uint public middleAmount;
  uint public rightAmount;
  uint public numberOfBet;

  address [] public players;
  mapping(address => Player) public playerInfo;

  /**
   * @dev Throws if called by any account other than the dealer
   */
  modifier onlyDealer() {
    require(msg.sender == betInfo.dealer);
    _;
  }

  function() payable public {}

  BetInfo betInfo;

  function Bet(address _dealer, bytes32 _category, bytes32 _gameId, uint _minimumBet, 
                  uint8 _spread, uint16 _leftOdds, uint16 _middleOdds, uint16 _rightOdds, uint8 _flag,
                  uint _startTime, uint8 _neededConfirmations, address _owner) payable public {
    require(_flag == 1 || _flag == 3);
    require(_startTime > now);
    require(msg.value >= 0.1 ether);
    require(_neededConfirmations >= neededConfirmations);

    betInfo.dealer = _dealer;
    betInfo.deposit = msg.value;
    betInfo.flag = _flag;
    betInfo.category = _category;
    betInfo.gameId = _gameId;
    betInfo.minimumBet = _minimumBet;
    betInfo.spread = _spread;
    betInfo.leftOdds = _leftOdds;
    betInfo.middleOdds = _middleOdds;
    betInfo.rightOdds = _rightOdds;
    betInfo.startTime = _startTime;

    neededConfirmations = _neededConfirmations;
    owner = _owner;
  }

  /**
   * @dev get basic information of this bet
   */
  function getBetInfo() public view returns (bytes32, bytes32, uint8, uint8, uint16, uint16, uint16, uint, uint, uint, address) {
    return (betInfo.category, betInfo.gameId, betInfo.spread, betInfo.flag, betInfo.leftOdds, betInfo.middleOdds,
            betInfo.rightOdds, betInfo.minimumBet, betInfo.startTime, betInfo.deposit, betInfo.dealer);
  }

  /**
   * @dev get basic information of this bet
   *
   *  uint public numberOfBet;
   *  uint public totalBetAmount = 0;
   *  uint public leftAmount;
   *  uint public middleAmount;
   *  uint public rightAmount;
   *  uint public deposit;
   */
  function getBetMutableData() public view returns (uint, uint, uint, uint, uint, uint) {
    return (numberOfBet, totalBetAmount, leftAmount, middleAmount, rightAmount, betInfo.deposit);
  }

  /**
   * @dev get bet result information
   *
   *  uint8 public winChoice;
   *  uint8 public confirmations = 0;
   *  uint8 public neededConfirmations = 1;
   *  uint16 public leftPts;
   *  uint16 public rightPts;
   *  bool public isBetClosed = false;
   */
  function getBetResult() public view returns (uint8, uint8, uint8, uint16, uint16, bool) {
    return (winChoice, confirmations, neededConfirmations, leftPts, rightPts, isBetClosed);
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
      needAmount = (leftAmount.add(amount)).mul(betInfo.leftOdds).div(100);
    } else if (choice == 2) {
      needAmount = (middleAmount.add(amount)).mul(betInfo.middleOdds).div(100);
    } else {
      needAmount = (rightAmount.add(amount)).mul(betInfo.rightOdds).div(100);
    }

    if (needAmount.add(getRefundTxFee()) > totalBetAmount.add(amount).add(betInfo.deposit)) {
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
      leftAmount = leftAmount.add(amount);
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
    require(now < betInfo.startTime);
    require(choice == 1 ||  choice == 2 || choice == 3);
    require(msg.value >= betInfo.minimumBet);
    require(!checkPlayerExists(msg.sender));

    if (!isSolvent(choice, msg.value)) {
      revert();
    }

    playerInfo[msg.sender].betAmount = msg.value;
    playerInfo[msg.sender].choice = choice;

    totalBetAmount = totalBetAmount.add(msg.value);
    numberOfBet = numberOfBet.add(1);
    updateAmountOfEachChoice(choice, msg.value);
    players.push(msg.sender);
    LogParticipant(msg.sender, choice, msg.value);
  }

  /**
   * @dev in order to let more people participant, dealer can recharge
   */
  function rechargeDeposit() public payable {
    require(msg.value >= betInfo.minimumBet);
    betInfo.deposit = betInfo.deposit.add(msg.value);
  }

  /**
   * @dev given game result, _return win choice by specific spread
   */
  function getWinChoice(uint _leftPts, uint _rightPts) public view returns (uint8) {
    uint8 _winChoice;
    if (betInfo.spread == 0) {
      if (_leftPts > _rightPts) {
        _winChoice = 1;
      } else if (_leftPts == _rightPts) {
        _winChoice = 2;
      } else {
        _winChoice = 3;
      }
    } else {
      if (betInfo.flag == 1) {
        if (_leftPts + betInfo.spread > _rightPts) {
          _winChoice = 1;
        } else {
          _winChoice = 3;
        }
      } else {
        if (_rightPts + betInfo.spread > _leftPts) {
          _winChoice = 3;
        } else {
          _winChoice = 1;
        }
      }
    }
    return _winChoice;
  }

  /**
   * @dev manualCloseBet could only be called by owner,
   *      this method only be used for ropsten,
   *      when ethereum-events-data deployed,
   *      game result should not be upload by owner
   */
  function manualCloseBet(uint16 _leftPts, uint16 _rightPts) onlyOwner external {
    leftPts = _leftPts;
    rightPts = _rightPts;

    LogGameResult(betInfo.category, betInfo.gameId, leftPts, rightPts);

    winChoice = getWinChoice(leftPts, rightPts);

    if (winChoice == 1) {
      distributeReward(betInfo.leftOdds);
    } else if (winChoice == 2) {
      distributeReward(betInfo.middleOdds);
    } else {
      distributeReward(betInfo.rightOdds);
    }

    isBetClosed = true;
    LogBetClosed(false, now);
    withdraw();
  }

  /**
   * @dev closeBet could be called by everyone, but owner/dealer should to this.
   */
  function closeBet() external {
    (leftPts, rightPts, confirmations) = dataCenterGetResult(betInfo.gameId);

    require(confirmations >= neededConfirmations);

    LogGameResult(betInfo.category, betInfo.gameId, leftPts, rightPts);

    winChoice = getWinChoice(leftPts, rightPts);

    if (winChoice == 1) {
      distributeReward(betInfo.leftOdds);
    } else if (winChoice == 2) {
      distributeReward(betInfo.middleOdds);
    } else {
      distributeReward(betInfo.rightOdds);
    }

    isBetClosed = true;
    LogBetClosed(false, now);
    withdraw();
  }

  /**
   * @dev get the players
   */
  function getPlayers() view public returns (address[]) {
    return players;
  }

  /**
   * @dev get contract balance
   */
  function getBalance() view public returns (uint) {
    return address(this).balance;
  }

  /**
   * @dev if there are some reasons lead game postpone or cancel
   *      the bet will also cancel and refund every bet
   */
  function refund() onlyOwner public {
    for (uint i = 0; i < players.length; i++) {
      players[i].transfer(playerInfo[players[i]].betAmount);
      LogRefund(players[i], playerInfo[players[i]].betAmount);
    }

    isBetClosed = true;
    LogBetClosed(true, now);
    withdraw();
  }

  /**
   * @dev dealer can withdraw the remain ether after refund or closed
   */
  function withdraw() internal {
    require(isBetClosed);
    uint _balance = address(this).balance;
    betInfo.dealer.transfer(_balance);
    LogDealerWithdraw(betInfo.dealer, _balance);
  }

  /**
   * @dev distribute ether to every winner as they choosed odds
   */
  function distributeReward(uint winOdds) internal {
    for (uint i = 0; i < players.length; i++) {
      if (playerInfo[players[i]].choice == winChoice) {
        players[i].transfer(winOdds.mul(playerInfo[players[i]].betAmount).div(100));
        LogDistributeReward(players[i], winOdds.mul(playerInfo[players[i]].betAmount).div(100), i);
      }
    }
  }
}
