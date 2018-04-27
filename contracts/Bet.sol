pragma solidity ^0.4.18;

// import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
// import "github.com/Arachnid/solidity-stringutils/strings.sol";

import './utils/usingOraclize.sol';
import './utils/strings.sol';
import './utils/SafeMath.sol';

contract Bet is usingOraclize {
  using strings for *;
  using SafeMath for uint;
  address public owner;

  event LogDistributeReward(address addr, uint reward);
  event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, string result);
  event LogParticipant(address addr, uint choice, uint betAmount);

  /** 
   * @desc
   * gameId: is a fixed string just like "0021701030"
   *   the full gameId encode(include football, basketball, esports..) will publish on github
   * leftOdds: need divide 100, if odds is 216 means 2.16
   * middleOdds: need divide 100, if odds is 175 means 1.75
   * rightOdds: need divide 100, if odds is 250 means 2.50
   * spread: need add 0.5, if spread is 0 means 0.5
   */
  bytes32 public category;
  bytes32 public gameId;
  uint public minimumBet;
  uint public spread;
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
   * duration: Indicate the time _this game will last
   */
  address public dealer;
  uint public deposit = 0;
  uint public totalBetAmount = 0;
  uint public leftAmount;
  uint public middleAmount;
  uint public rightAmount;
  uint public numberOfBet;
  uint public leftPts;
  uint public rightPts;
  uint public winChoice;
  uint public flag;
  uint public startTime;
  uint public duration = 3600 * 3;

  address [] players;
  mapping(address => Player) public playerInfo;

  function() payable public {}

  function Bet(address _dealer, bytes32 _category, bytes32 _gameId, uint _minimumBet, 
                  uint _spread, uint _leftOdds, uint _middleOdds, uint _rightOdds, uint _flag,
                  uint _startTime, uint _duration) payable public {
    require(_startTime > now);
    require(msg.value >= 0.1 ether);
    owner = msg.sender;
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
    duration = _duration;

    // oraclize_setCustomGasPrice(4000000000 wei);
    // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);

    // Set a delay close function
    // close();
  }

  /**
   * @dev compose a url can get the result of game
   * @param _gameId The unique identity of a game
   */
  function getQueryUrl(bytes32 _gameId) internal pure returns (string) {
    strings.slice[] memory parts = new strings.slice[](3);
    parts[0] = 'json(http://api.ttnbalite.com/api/nba/game/query/?game_id='.toSlice();
    parts[1] = _gameId.toSliceB32();
    parts[2] = ').data.result'.toSlice();
    return ''.toSlice().join(parts);
  }

  /**
   * @dev close this bet
   * @notice need modify to internal
   */
  function close() public {
    if (oraclize_getPrice("URL") > address(this).balance) {
      refund();
    } else {
      string memory url = getQueryUrl(gameId);
      // oraclize_query(duration, "URL", url);
      oraclize_query(0, "URL", url);
    }
  }

  /**
   * @dev calculate the gas whichdistribute rewards will cost
   * set default gasPrice is 5000000000
   */
  function getRefundTxFee() view public returns (uint) {
    return numberOfBet.mul(5000000000 * 21000);
  }

  /**
   * @dev find a player has participanted or not
   * @param player the address of the participant
   */
  function checkPlayerExists(address player) view public returns (bool) {
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
  function isSolvent(uint choice, uint amount) view internal returns (bool) {
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
   *
   */
  function rechargeDeposit() public payable {
    require(msg.value >= minimumBet);
    deposit = deposit.add(msg.value);
  }

  /**
   * @dev oraclize will call this function with result
   * @param result will be like 117-103(left team is away team) or 1-3(left team is home team)
   * @notice comment out `myid` to avoid 'unused parameter' warning
   */
  function __callback(bytes32 /*myid*/, string result) public {
    require(msg.sender == oraclize_cbAddress());
    require(flag == 1 || flag == 2);

    LogGameResult(category, gameId, result);
    var needle = '-'.toSlice();
    leftPts = parseInt(result.toSlice().copy().split(needle).toString());
    rightPts = parseInt(result.toSlice().copy().rsplit(needle).toString());

    if (flag == 1) {
      if (rightPts + spread >= leftPts) {
        winChoice = 2;
      } else {
        winChoice = 1;
      }
    } else {
      if (leftPts + spread >= rightPts) {
        winChoice = 1;
      } else {
        winChoice = 2;
      }
    }

    require(winChoice == 1 || winChoice == 2);
    if (winChoice == 1) {
      distributeReward(leftOdds);
    } else {
      distributeReward(rightOdds);
    }
  }

  function refund() public {
    for(uint i = 0; i < players.length; i++) {
      address playerAddress = players[i];
      playerAddress.transfer(playerInfo[playerAddress].betAmount);
    }
  }

  function testDistribute(uint winOdds) public {
    for(uint i = 0; i < players.length; i++) {
      address playerAddress = players[i];
      if(playerInfo[playerAddress].choice == winChoice) {
        // Distribute ether to winners
        LogDistributeReward(playerAddress, winOdds * playerInfo[playerAddress].betAmount / 100);
        playerAddress.transfer(winOdds * playerInfo[playerAddress].betAmount / 100);
      }
    }
  }

  function distributeReward(uint winOdds) internal {
    for(uint i = 0; i < players.length; i++) {
      address playerAddress = players[i];
      if(playerInfo[playerAddress].choice == winChoice) {
        // Distribute ether to winners
        playerAddress.transfer(winOdds * playerInfo[playerAddress].betAmount / 100);
      }
      delete playerInfo[playerAddress];
    }
    players.length = 0;
  }
}
