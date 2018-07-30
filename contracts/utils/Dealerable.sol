pragma solidity ^0.4.19;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 *      functions, this simplifies the implementation of "user permissions"
 */
contract Dealerable {
  address public dealer;

  event DealershipTransferred(address indexed previousDealer, address indexed newDealer);

  /**
   * @dev Throws if called by any account other than the dealer
   */
  modifier onlyDealer() {
    require(msg.sender == dealer);
    _;
  }

  /**
   * @dev The Dealerable constructor sets the original `dealer` of the contract to the sender
   *      account
   */
  function Dealerable() public {
    dealer = msg.sender;
  }

  /**
   * @dev Allows the current dealer to transfer control of the contract to a newDealer
   * @param newDealer The address to transfer dealership to
   */
  function dealershipTransferred(address newDealer) public onlyDealer {
    require(newDealer != address(0));
    DealershipTransferred(dealer, newDealer);
    dealer = newDealer;
  }
}
