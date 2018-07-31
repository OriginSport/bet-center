pragma solidity ^0.4.24;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

/**
 * Bet base model
 *
 * @author bingo
 */
contract BetBase is Ownable {
    using SafeMath for uint;

    event LogDistributeReward(address indexed addr, uint reward, uint index);
//    event LogGameResult(bytes32 indexed category, bytes32 indexed gameId, uint leftPts, uint rightPts);
    event LogGameResult(bytes32 indexed category, uint leftPts, uint rightPts);
    event LogParticipant(address indexed addr, uint choice, uint betAmount);
    event LogRefund(address indexed addr, uint betAmount);
    event LogBetClosed(bool isRefund, uint timestamp);
    event LogDealerWithdraw(address indexed addr, uint withdrawAmount);

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
//    struct BetInfo {
//        bytes32 category;
//        bytes32 gameId;
//        uint8 spread;
//        uint8 flag;
//        uint16 leftOdds;
//        uint16 middleOdds;
//        uint16 rightOdds;
//        uint minimumBet;
//        uint startTime;
//        uint deposit;
//        address dealer;
//    }

    bytes32 public category;
//    bytes32 public gameId;
    uint8 public spread;
    uint8 public flag;
    /** odds[1]:leftOdds, odds[2]:middleOdds, odds[3]:rightOdds */
    mapping(uint8 => uint16) odds;
    uint public minimumBet;
    uint public startTime;
    uint public deposit;
    address public dealer;

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
    uint16 public leftPts;
    uint16 public rightPts;
    bool public isBetClosed = false;

//    uint public totalBetAmount = 0;
//    uint public leftAmount;
//    uint public middleAmount;
//    uint public rightAmount;
//    uint public numberOfBet;
    /** amounts[0]:totalAmount, amounts[1]:leftAmount, amounts[2]:middleAmount, amounts[3]:rightAmount */
    mapping(uint => uint) public amounts;

    address[] public players;
    mapping(address => Player) public playerInfo;

    /**
     * @dev Throws if called by any account other than the dealer
     */
    modifier onlyDealer() {
        require(msg.sender == dealer);
        _;
    }

    function() payable public {}

//    BetInfo betInfo;

    constructor(address _dealer, bytes32 _category, uint _minimumBet, uint8 _spread, uint16 _leftOdds, uint16 _middleOdds, uint16 _rightOdds,
        uint8 _flag, uint _startTime, address _owner) payable public {
        require(_flag == 1 || _flag == 3);
        require(_startTime > now);
        require(msg.value >= minimumBet.mul(_leftOdds) && msg.value >= minimumBet.mul(_middleOdds) && msg.value >= minimumBet.mul(_rightOdds));

        dealer = _dealer;
        deposit = msg.value;
        flag = _flag;
        category = _category;
        minimumBet = _minimumBet;
        spread = _spread;
        odds[1] = _leftOdds;
        odds[2] = _middleOdds;
        odds[3] = _rightOdds;
        startTime = _startTime;
        owner = _owner;
    }

    /**
     * @dev get basic information of this bet
     */
    function getBetInfo() public view returns (bytes32, uint8, uint8, uint16, uint16, uint16, uint, uint, uint, address) {
        return (category, spread, flag, odds[1], odds[2], odds[3], minimumBet, startTime, deposit, dealer);
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
        return (players.length, amounts[0], amounts[1], amounts[2], amounts[3], deposit);
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
    function getBetResult() public view returns (uint8, uint16, uint16, bool) {
        return (winChoice, leftPts, rightPts, isBetClosed);
    }

    /**
     * @dev calculate the gas whichdistribute rewards will cost
     * set default gasPrice is 5000000000
     */
//    function getRefundTxFee() public view returns (uint) {
//        return numberOfBet.mul(5000000000 * 21000);
//    }

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
    function isSolvent(uint8 choice, uint amount) internal view returns (bool) {
        uint needAmount;
//        if (choice == 1) {
//            needAmount = (leftAmount.add(amount)).mul(leftOdds).div(100);
//        } else if (choice == 2) {
//            needAmount = (middleAmount.add(amount)).mul(middleOdds).div(100);
//        } else {
//            needAmount = (rightAmount.add(amount)).mul(rightOdds).div(100);
//        }
        needAmount = amounts[choice] = (amounts[choice].add(amount)).mul(odds[choice]).div(100);
        
//        if (needAmount.add(getRefundTxFee()) > amounts[0].add(amount).add(deposit)) {
        if (needAmount > amounts[0].add(amount).add(deposit)) {
            return false;
        }
        return true;
    }

    /**
     * @dev update this bet some state
     * @param choice indicate which team user choose
     * @param amount indicate how many ether user bet
     */
    function updateAmountOfEachChoice(uint choice, uint amount) internal {
//        if (choice == 1) {
//            leftAmount = leftAmount.add(amount);
//        } else if (choice == 2) {
//            middleAmount = middleAmount.add(amount);
//        } else {
//            rightAmount = rightAmount.add(amount);
//        }
        amounts[choice] = amounts[choice].add(amount);
    }

    /**
     * @dev place a bet with his/her choice
     * @param choice indicate which team user choose
     */
    function placeBet(uint choice) public payable {
        require(now < startTime);
        require(choice == 1 || choice == 2 || choice == 3);
        require(msg.value >= minimumBet);
        require(!checkPlayerExists(msg.sender));

        if (!isSolvent(choice, msg.value)) {
            revert();
        }

        playerInfo[msg.sender].choice = choice;
        playerInfo[msg.sender].betAmount = msg.value;
        amounts[0] = amounts[0].add(msg.value);
//        numberOfBet = numberOfBet.add(1);
//        updateAmountOfEachChoice(choice, msg.value);
        amounts[choice] = amounts[choice].add(msg.value);
        players.push(msg.sender);

        emit LogParticipant(msg.sender, choice, msg.value);
    }

    /**
     * @dev in order to let more people participant, dealer can recharge
     */
    function rechargeDeposit() public payable {
        require(msg.value >= minimumBet);
        deposit = deposit.add(msg.value);
    }

    /**
     * @dev given game result, _return win choice by specific spread
     */
    function getWinChoice(uint _leftPts, uint _rightPts) public view returns (uint8) {
        uint8 _winChoice;
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
     * @dev manualCloseBet could only be called by owner,
     *      this method only be used for ropsten,
     *      when ethereum-events-data deployed,
     *      game result should not be upload by owner
     */
    function manualCloseBet(uint16 _leftPts, uint16 _rightPts) onlyOwner external {
        require(now > startTime);
        require(!isBetClosed);
        leftPts = _leftPts;
        rightPts = _rightPts;
        winChoice = getWinChoice(leftPts, rightPts);

//        if (winChoice == 1) {
//            distributeReward(leftOdds);
//        } else if (winChoice == 2) {
//            distributeReward(middleOdds);
//        } else {
//            distributeReward(rightOdds);
//        }
        distributeReward(odds[winChoice]);

        isBetClosed = true;
        withdraw();

        emit LogBetClosed(false, now);
        emit LogGameResult(category, leftPts, rightPts);
    }

    /**
     * @dev closeBet could be called by everyone, but owner/dealer should to this.
     */
    function closeBet(uint8 _winChoice) onlyOwner external {
        require(now > startTime);
        require(!isBetClosed);

        winChoice = _winChoice;
//        if (winChoice == 1) {
//            distributeReward(leftOdds);
//        } else if (winChoice == 2) {
//            distributeReward(middleOdds);
//        } else {
//            distributeReward(rightOdds);
//        }
        distributeReward(odds[_winChoice]);

        isBetClosed = true;
        withdraw();
        emit LogBetClosed(false, now);
        emit LogGameResult(category, leftPts, rightPts);
    }

    /**
     * @dev if there are some reasons lead game postpone or cancel
     *      the bet will also cancel and refund every bet
     */
    function refund() onlyOwner public {
        for (uint i = 0; i < players.length; i++) {
            players[i].transfer(playerInfo[players[i]].betAmount);
            emit LogRefund(players[i], playerInfo[players[i]].betAmount);
        }

        isBetClosed = true;
        withdraw();

        emit LogBetClosed(true, now);
    }

    /**
     * @dev dealer can withdraw the remain ether after refund or closed
     */
    function withdraw() internal {
        require(isBetClosed);
        uint _balance = address(this).balance;
        dealer.transfer(_balance);
        emit LogDealerWithdraw(dealer, _balance);
    }

    /**
     * @dev distribute ether to every winner as they choosed odds
     */
    function distributeReward(uint winOdds) internal {
        for (uint i = 0; i < players.length; i++) {
            if (playerInfo[players[i]].choice == winChoice) {
                players[i].transfer(winOdds.mul(playerInfo[players[i]].betAmount).div(100));
                emit LogDistributeReward(players[i], winOdds.mul(playerInfo[players[i]].betAmount).div(100), i);
            }
        }
    }
}
