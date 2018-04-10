pragma solidity ^0.4.18;

// import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
// import "github.com/Arachnid/solidity-stringutils/strings.sol";

import './utils/usingOraclize.sol';
import './utils/strings.sol';

contract Bet is usingOraclize {
  using strings for *;
  address public owner;

  event LogDistributeReward(address addr, uint reward);
  event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, string result);
  event LogPlayerChoice(address addr, uint choice);

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
  uint public deposit;
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
   *   1 means leftTeam, 2 means rightTeam, 4 means draw(leftTeam is not always equivalent to the home team)
   * flag: Indicate which team take spread
   *   1 means leftTeam, 2 means rightTeam
   * duration: Indicate the time _this game will last
   */
  uint public totalBetAmount;
  uint public leftAmount;
  uint public middleAmount;
  uint public rightAmount;
  uint public numberOfBet;
  uint public leftPts;
  uint public rightPts;
  uint public winChoice;
  uint public flag;
  uint public duration = 3600 * 3;

  address [] players;
  mapping(address => Player) public playerInfo;

  function() payable public {}

  function Bet(bytes32 _category, bytes32 _gameId, uint _deposit, uint _minimumBet, 
                  uint _spread, uint _leftOdds, uint _middleOdds, uint _rightOdds, uint _flag) payable public {
    owner = msg.sender;

    flag = _flag;
    category = _category;
    gameId = _gameId;
    deposit = _deposit;
    minimumBet = _minimumBet;
    spread = _spread;
    leftOdds = _leftOdds;
    middleOdds = _middleOdds;
    rightOdds = _rightOdds;

    // oraclize_setCustomGasPrice(4000000000 wei);
    // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);

    // Set a delay close function
    // close();
  }

  function getQueryUrl(bytes32 _gameId) internal pure returns (string) {
    strings.slice[] memory parts = new strings.slice[](3);
    parts[0] = 'json(http://api.ttnbalite.com/api/nba/game/query/?game_id='.toSlice();
    parts[1] = _gameId.toSliceB32();
    parts[2] = ').data.result'.toSlice();
    return ''.toSlice().join(parts);
  }

  function close() public {
    if (oraclize_getPrice("URL") > address(this).balance) {
      refund();
    } else {
      string memory url = getQueryUrl(gameId);
      // oraclize_query(duration, "URL", url);
      oraclize_query(0, "URL", url);
    }
  }

  function checkPlayerExists(address player) view public returns (bool) {
    if (playerInfo[player].choice > 0) {
      return true;
    }
    return false;
  }

  function isSolvent(uint choice, uint amount) view internal returns (bool) {
    uint needAmount;
    if (choice == 1) {
      needAmount = leftOdds * (leftAmount + amount) / 100;
    } else if (choice == 2) {
      needAmount = middleOdds * (middleAmount + amount) / 100;
    } else {
      needAmount = rightOdds * (rightAmount + amount) / 100;
    }

    if (needAmount > totalBetAmount + amount + deposit) {
      return true;
    } else {
      return false;
    }
  }

  function placeBet(uint choice) public payable {
    require(choice == 1 ||  choice == 2 || choice == 3);
    require(msg.value >= minimumBet);

    if (!isSolvent(choice, msg.value)) {
      revert();
    }

    playerInfo[msg.sender].betAmount += msg.value;
    playerInfo[msg.sender].choice = choice;

    totalBetAmount += msg.value;
    numberOfBet += 1;
    LogPlayerChoice(msg.sender, choice);
  }

  function __callback(bytes32 myid, string result) public {
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

  function refund() {
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
