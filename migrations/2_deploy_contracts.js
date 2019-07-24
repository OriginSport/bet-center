// const BetCenter = artifacts.require('BetCenter.sol')
const BetHelper = artifacts.require('BetHelper.sol')

module.exports = function(deployer) {
  // deployer.deploy(BetCenter)
  deployer.deploy(BetHelper)
}
