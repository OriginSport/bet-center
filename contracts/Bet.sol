pragma solidity ^0.4.18;

// import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
// import "github.com/Arachnid/solidity-stringutils/strings.sol";

import './utils/usingOraclize.sol';
import './utils/strings.sol';

contract Bet is usingOraclize {
  using strings for *;

  event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, string result);
  event LogPlayerChoice(address addr, uint choice);

  /** 
    gameId: is a fixed string just like "0021701030"
      the full gameId encode(include football, basketball, esports..) will publish on github
    awayOdds: need divide 100, if odds is 216 means 2.16
    homeOdds: need divide 100, if odds is 216 means 2.16
    spread: need add 0.5, if spread is 0 means 0.5
    */
  bytes32 public category;
  bytes32 public gameId;
  uint public deposit;
  uint public minimumBet;
  uint public spread;
  uint public awayOdds;
  uint public homeOdds;

  struct Player {
    uint betAmount;
    uint choice;
  }

  uint public totalBetAmount;
  uint public numberOfBet;
  uint public awayPts;
  uint public homePts;
  // 1 means awayTeam win, 2 means homeTeam win
  uint public winChoice;
  uint public maxOdds;
  // flag indicate which team take spread, 1 means awayTeam, 2 means homeTeam
  uint public flag;
  // winOdds determine the odds of winners
  uint public winOdds;
  uint public duration = 3600 * 3;
  address[] public players;

  mapping(address => Player) public playerInfo;

  function() payable public {}

  function setMaxOdds(uint odds1, uint odds2) internal returns (uint) {
    if (odds1 > odds2) {
      return odds1;
    } else {
      return odds2;
    }
  }

  function Bet(bytes32 _category, bytes32 _gameId, uint _deposit, uint _minimumBet, 
                  uint _spread, uint _awayOdds, uint _homeOdds, uint _flag) payable public {
    flag = _flag;
    setMaxOdds(awayOdds, homeOdds);
    category = _category;
    gameId = _gameId;
    deposit = _deposit;
    minimumBet = _minimumBet;
    spread = _spread;
    awayOdds = _awayOdds;
    homeOdds = _homeOdds;
    
    // oraclize_setCustomGasPrice(4000000000 wei);
    // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
  }

  function getQueryUrl(bytes32 gameId) internal returns (string) {
    strings.slice[] memory parts = new strings.slice[](3);
    parts[0] = 'json(http://api.ttnbalite.com/api/nba/game/query/?game_id='.toSlice();
    parts[1] = gameId.toSliceB32();
    parts[2] = ').data.result'.toSlice();
    return ''.toSlice().join(parts);
  }

  function close() payable {
    if (oraclize_getPrice("URL") > address(this).balance) {
    } else {
      string memory url = getQueryUrl(gameId);
      oraclize_query(duration, "URL", url);
    }
  }

  function checkPlayerExists(address player) view public returns (bool) {
    for(uint i = 0; i < players.length; i++) {
      if(players[i] == player) return true;
    }
    return false;
  }

  function placeBet(uint choice) public payable {
    require(!checkPlayerExists(msg.sender));
    require(choice == 1 ||  choice == 2);
    require(msg.value >= minimumBet);
    require(maxOdds * (totalBetAmount + msg.value) / 100 > deposit);

    playerInfo[msg.sender].betAmount = msg.value;
    playerInfo[msg.sender].choice = choice;

    totalBetAmount += msg.value;
    players.push(msg.sender);
    LogPlayerChoice(msg.sender, choice);
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress());
    require(flag == 1 || flag == 2);

    LogGameResult(category, gameId, result);
    var needle = '-'.toSlice();
    awayPts = parseInt(result.toSlice().copy().split(needle).toString());
    homePts = parseInt(result.toSlice().copy().rsplit(needle).toString());

    if (flag == 1) {
      if (homePts + spread >= awayPts) {
        winChoice = 2;
      } else {
        winChoice = 1;
      }
    } else {
      if (awayPts + spread >= homePts) {
        winChoice = 1;
      } else {
        winChoice = 2;
      }
    }

    require(winChoice == 1 || winChoice == 2);
    if (winChoice == 1) {
      winOdds = awayOdds;
    } else {
      winOdds = homeOdds;
    }

    distributeReward();
  }

  function distributeReward() public {
    address[100] memory winners;
    uint count = 0;

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
