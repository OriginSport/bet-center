var Bet = artifacts.require('./Bet.sol')

contract('Bet', function(accounts) {
  it('create a new game for game 0021701030', function() {
    return NbaBet.deployed().then(function(instance) {
      return instance.createBet.sendTransaction('0021701030', {from: accounts[0], value: 5e18})
        .then(function(balance) {
          value = web3.eth.getBalance(bet.address).valueOf()
          assert.isAtLeast(value, 4.9e18, "There were not 5 ether in the contract.")
        })
    })
  })
})
