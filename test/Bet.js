var Bet = artifacts.require('./Bet.sol')
var BetCenter = artifacts.require('./BetCenter.sol')
var web3 = require('web3')
const { addsDayOnEVM, assertRevert } = require('./helpers')

// return web3.utils.fromAscii(str)
// return web3.utils.hexToAscii(bytes32)

function getStr(hexStr) {
  return web3.utils.hexToAscii(hexStr).replace(/\u0000/g, '')
}
function getBytes(str) {
  return web3.utils.fromAscii(str)
}

contract('Bet', accounts => {
  // account[0] points to the owner on the testRPC setup
  var owner = accounts[0]
  var dealer = accounts[1]
  var user1 = accounts[2]
  var user2 = accounts[3]
  var user3 = accounts[4]
  console.log(`dealer:${dealer}\nuser1:${user1}\nuser2:${user2}`)

  let bet
  let betCenter
  let totalBetAmount = 0
  let players = []
  const minimum_bet = 5e16
  const leftOdds = 250
  const middleOdds = 175
  const rightOdds = 120
  const deposit = 1e18
  const params = [getBytes('NBA'), getBytes('0021701030'), minimum_bet, 0, leftOdds, middleOdds, rightOdds, 1, 1528988400, 3600*3]

  before(() => {
    return BetCenter.deployed({from: owner})
    .then(instance => {
      betCenter = instance
      return betCenter.createBet(...params, {gas: 4300000, from: dealer, value: 1e17})
    })
    .then(events => {
      const addr = events.logs[0].args.betAddr
      bet = Bet.at(addr)
    })
  })

  it('should return a bet', async () => {
    const categoryBets = await betCenter.getBetsByCategory(params[0])
    assert.equal(categoryBets.length, 1)
  })

  it('check bet params is correct', async () => {
    const category = await bet.category()
    const minimumBet = (await bet.minimumBet()).toNumber()
    assert.equal(getStr(category), 'NBA')
    assert.equal(minimumBet, minimum_bet)
  })

  it('test place bet choice i odds is too large that dealer is insolvent', async () => {
    const betAmount = 1e17
    const choice = 1
    const addr = user1
    await assertRevert(bet.placeBet(choice, {from: addr, value: betAmount}))
  })

  it('test another user place bet', async () => {
    const betAmount = 1e17
    const choice = 2
    const addr = user2
    const tx = await bet.placeBet(choice, {from: addr, value: betAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += betAmount
    players.push(addr)
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(tx.logs[0].args.betAmount, betAmount)
    assert.equal(playerInfo[0].toNumber(), betAmount)
    assert.equal(playerInfo[1].toNumber(), choice)
    assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
  })

  it('test the third user place bet', async () => {
    const betAmount = 1e17
    const choice = 3
    const addr = user3
    const tx = await bet.placeBet(choice, {from: addr, value: betAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += betAmount
    players.push(addr)
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(playerInfo[0].toNumber(), betAmount)
    assert.equal(playerInfo[1].toNumber(), choice)
    assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
  })

  it('test the forth user place bet', async () => {
    const betAmount = 1e17
    const choice = 1
    const addr = user1
    const tx = await bet.placeBet(choice, {from: addr, value: betAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += betAmount
    players.push(addr)
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(playerInfo[0].toNumber(), betAmount)
    assert.equal(playerInfo[1].toNumber(), choice)
    assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
  })

  it('test recharge deposit', async () => {
    const chargeValue = 1e17
    const oldDeposit = (await bet.deposit()).toNumber()
    const tx = await bet.rechargeDeposit({from: dealer, value: chargeValue})
    const newDeposit = (await bet.deposit()).toNumber()

    assert.equal(oldDeposit + chargeValue, newDeposit)
  })

  after(async () => {
    players.forEach(async player => {
      const playerInfo = await bet.playerInfo(player)
      console.log(web3.utils.fromWei(String(playerInfo[0].toNumber())), playerInfo[1].toNumber())
    })
  })

})

