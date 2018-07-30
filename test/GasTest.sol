//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.19;
contract TestGas {
  
  address target;
  address [] public players;

  string constant statictext = "Hello World";
  bytes11 constant byteText11 = "Hello World";
  bytes32 constant byteText32 = "Hello World";

  function TestGas() public {
    players.push(0x00c6bFFba6eD9EA434AcB096D171C0a78e24D318);
    players.push(0x7525C82e0cf1832E79Ff3AFf259C5Fe853CF95F4);
    players.push(0x00c6bFFba6eD9EA434AcB096D171C0a78e24D318);
    players.push(0x7525C82e0cf1832E79Ff3AFf259C5Fe853CF95F4);
    players.push(0x00c6bFFba6eD9EA434AcB096D171C0a78e24D318);
    players.push(0x7525C82e0cf1832E79Ff3AFf259C5Fe853CF95F4);
    players.push(0x00c6bFFba6eD9EA434AcB096D171C0a78e24D318);
  }

  // gas spent 21875
  function  getString() payable public  returns(string){
    return statictext;
  }

  // gas spent 21509
  function  getByte11() payable public returns(bytes11){
    return byteText11;
  }

  // gas spent 21487
  function  getByte32() payable public returns(bytes32){
    return byteText32;
  }
  
  
  // gas spent 64104
  function refund1() payable public {
    for (uint i = 0; i < players.length; i++) {
      address addr = players[i];
      target = addr;
    }
  }

  // gas spent 64021
  function refund2() payable public {
    for (uint i = 0; i < players.length; i++) {
      target = players[i];
    }
  }
}
