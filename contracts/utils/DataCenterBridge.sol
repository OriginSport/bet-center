pragma solidity ^0.4.19;

contract DataCenterInterface {
  function getResult(bytes32 gameId) view public returns (uint16, uint16, uint8);
}
contract DataCenterAddrResolverInterface {
  function getAddress() public returns (address _addr);
}
contract DataCenterBridge {
  uint8 constant networkID_auto = 0;
  uint8 constant networkID_mainnet = 1;
  uint8 constant networkID_testnet = 2;
  string networkName;

  address mainnetAddr = 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
  address testnetAddr = 0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB;

  DataCenterAddrResolverInterface DAR;

  DataCenterInterface dataCenter;

  modifier dataCenterAPI() {
    if((address(DAR) == 0) || (getCodeSize(address(DAR)) == 0))
      setNetwork(networkID_auto);
    if(address(dataCenter) != DAR.getAddress())
      dataCenter = DataCenterInterface(DAR.getAddress());
    _;
  }

  /**
   * @dev set network will indicate which net will be used
   * @notice comment out `networkID` to avoid 'unused parameter' warning
   */
  function setNetwork(uint8 /*networkID*/) internal returns(bool){
    return setNetwork();
  }

  function setNetwork() internal returns(bool){
    if (getCodeSize(mainnetAddr) > 0) {
      DAR = DataCenterAddrResolverInterface(mainnetAddr);
      setNetworkName("eth_mainnet");
      return true;
    }
    if (getCodeSize(testnetAddr) > 0) {
      DAR = DataCenterAddrResolverInterface(testnetAddr);
      setNetworkName("eth_ropsten");
      return true;
    }
    return false;
  }

  function setNetworkName(string _networkName) internal {
    networkName = _networkName;
  }

  function getNetworkName() internal view returns (string) {
    return networkName;
  }

  function dataCenterGetResult(bytes32 _gameId) dataCenterAPI internal returns (uint16, uint16, uint8){
    return dataCenter.getResult(_gameId);
  }

  function getCodeSize(address _addr) view internal returns (uint _size) {
    assembly {
      _size := extcodesize(_addr)
    }
  }
}
