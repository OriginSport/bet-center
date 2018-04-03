const BetCenter = artifacts.require('BetCenter.sol')

module.exports = function(deployer) {
  deployer.deploy(BetCenter)
}
