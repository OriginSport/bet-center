const BasketballBetPlatform = artifacts.require('BasketballBetPlatform.sol')

module.exports = function(deployer) {
  deployer.deploy(BasketballBetPlatform)
}
