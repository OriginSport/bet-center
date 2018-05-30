var Bet = artifacts.require('./Bet.sol')
var BetCenter = artifacts.require('./BetCenter.sol')
var w3 = require('web3')
const { addDaysOnEVM, assertRevert } = require('truffle-js-test-helper')

// return web3.utils.fromAscii(str)
// return web3.utils.hexToAscii(bytes32)
function getBalance (address) {
  return new Promise (function (resolve, reject) {
    web3.eth.getBalance(address, function (error, result) {
      if (error) {
        reject(error);
      } else {
        resolve(result);
      }
    })
  })
}

function getStr(hexStr) {
  return w3.utils.hexToAscii(hexStr).replace(/\u0000/g, '')
}
function getBytes(str) {
  return w3.utils.fromAscii(str)
}

contract('Bet', accounts => {
  // account[0] points to the owner on the testRPC setup
  var owner = accounts[0]
  var dealer = accounts[1]
  var user1 = accounts[2]
  var user2 = accounts[3]
  var user3 = accounts[4]
  console.log(`owner:${owner}\ndealer:${dealer}\nuser1:${user1}\nuser2:${user2}`)

  let bet
  let betCenter
  let scAddr
  let totalBetAmount = 0
  const minimum_bet = 5e16
  const leftOdds = 250
  const middleOdds = 175
  const rightOdds = 120
  const deposit = 1e18
  const params = [getBytes('NBA'), getBytes('0021701030'), minimum_bet, 0, leftOdds, middleOdds, rightOdds, 1, 1528988400, 3600*3]
  //const params = [getBytes('NBA'), getBytes('0021701030'), minimum_bet, 10, leftOdds, middleOdds, rightOdds, 3, 1528988400, 3600*3]
  console.log('The params of this bet: ', params)

  const testAmount = 1e17

  before(() => {
    return BetCenter.deployed({from: owner})
    .then(instance => {
      betCenter = instance
      return betCenter.createBet(...params, {gas: 4300000, from: dealer, value: deposit})
    })
    .then(events => {
      scAddr = events.logs[0].args.betAddr
      bet = Bet.at(scAddr)
    })
  })

  it('should return a bet', async () => {
    const categoryBets = await betCenter.getBetsByCategory(params[0])
    assert.equal(categoryBets.length, 1)
  })

  it('check bet params is correct', async () => {
    const category = await bet.category()
    const minimumBet = (await bet.minimumBet()).toNumber()
    const _leftOdds = await bet.leftOdds()
    const _rightOdds = await bet.rightOdds()
    const _middleOdds = await bet.middleOdds()

    assert.equal(_leftOdds.toNumber(), leftOdds)
    assert.equal(_rightOdds, rightOdds)
    assert.equal(_middleOdds, middleOdds)
    assert.equal(getStr(category), 'NBA')
    assert.equal(minimumBet, minimum_bet)
  })

  it('test place bet choice i odds is too large that dealer is insolvent', async () => {
    const betAmount = 1e18
    const choice = 1
    const addr = user1
    await assertRevert(bet.placeBet(choice, {from: addr, value: betAmount}))
  })

  it('test another user place bet', async () => {
    const choice = 2
    const addr = user2
    const tx = await bet.placeBet(choice, {from: addr, value: testAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += testAmount
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(tx.logs[0].args.betAmount, testAmount)
    assert.equal(playerInfo[0].toNumber(), testAmount)
    assert.equal(playerInfo[1].toNumber(), choice)
    assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
  })

  it('test the third user place bet', async () => {
    const choice = 3
    const addr = user3
    const tx = await bet.placeBet(choice, {from: addr, value: testAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += testAmount
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(playerInfo[0].toNumber(), testAmount)
    assert.equal(playerInfo[1].toNumber(), choice)
    assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
  })

  it('test the forth user place bet', async () => {
    const choice = 1
    const addr = user1
    const tx = await bet.placeBet(choice, {from: addr, value: testAmount})
    const _totalBetAmount = await bet.totalBetAmount()
    const playerInfo = await bet.playerInfo(addr)

    totalBetAmount += testAmount
    assert.equal(tx.logs[0].args.addr, addr)
    assert.equal(tx.logs[0].args.choice, choice)
    assert.equal(playerInfo[0].toNumber(), testAmount)
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

  it('test multi place bet', async () => {
    let choice = 1
    for (let i = 5; i < 100; i++) {
      choice = Math.floor(Math.random() * 3) + 1
      await bet.placeBet(choice, {from: accounts[i], value: testAmount})
    }
  })

  it('test manual close bet', async () => {
    web3.eth.getBalance(user1, function(err, data) {
      console.log('old balance: ', data)
    })
    const dealerB = await getBalance(dealer)
    const _lp = 118
    //const _rp = 118
    const _rp = 109
    const tx = await bet.manualCloseBet(_lp, _rp, { from: owner })
    //tx.logs.forEach(l => {
    //  console.log(l.args)
    //})
    const remainB = tx.logs[tx.logs.length-1].args.withdrawAmount.toNumber()
    console.log('remain balance is: ', remainB)
    console.log('=======================Winner number is: ', tx.logs.length - 1)
    const choice = await bet.winChoice()
    const lp = await bet.leftPts()
    const rp = await bet.rightPts()
    console.log('win choice: ', choice.toNumber())
    web3.eth.getBalance(user1, function(err, data) {
      console.log('new balance: ', data)
    })
    assert.equal(lp.toNumber(), _lp)
    assert.equal(rp.toNumber(), _rp)

    const _dealerB = await getBalance(dealer)
    assert.equal(dealerB.add(remainB).toNumber(), _dealerB.toNumber())
  })

  //it('test refund', async () => {

  //  const dealerB = await getBalance(dealer)
  //  const user1B = await getBalance(user1)
  //  const tx = await bet.refund({from: owner});
  //  const remainB = tx.logs[tx.logs.length-1].args.withdrawAmount.toNumber()
  //  console.log('refund remain balance is: ', remainB)
  //  const _user1B = await getBalance(user1)
  //  const _dealerB = await getBalance(dealer)
  //
  //  assert.equal(user1B.add(testAmount).toNumber(), _user1B.toNumber())
  //  assert.equal(dealerB.add(remainB).toNumber(), _dealerB.toNumber())
  //})

  // it('test withdraw', async () => {
  //   const b = await bet.getBalance()
  //   const dealerB = await getBalance(dealer)
  //   const tx = await bet.withdraw({from: dealer})
  //   const gasUsed = parseInt(tx.receipt.gasUsed) * 100000000000
  //   const _dealerB = await getBalance(dealer)
  //   assert.equal(dealerB.add(b).toNumber(), _dealerB.add(gasUsed).toNumber())
  // })

  after(async () => {
    const choice = await bet.winChoice()
    const players = await bet.getPlayers()
    const _totalBetAmount = await bet.totalBetAmount()
    const _deposit = await bet.deposit()
    console.log("The winner's choice is:   ", choice)
    console.log('Total bet amount is:      ', _totalBetAmount)
    console.log('Deposit amount is:        ', _deposit)
    console.log('Number of participant is: ', players.length)
  })
})

