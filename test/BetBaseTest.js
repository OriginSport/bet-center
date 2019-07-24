var BetBase = artifacts.require('./BetBase.sol')
var BetHelper = artifacts.require('./BetHelper.sol')
var w3 = require('web3')
const { setTimestamp, assertRevert } = require('truffle-js-test-helper')

function getBalance (address) {
    return new Promise (function (resolve, reject) {
        web3.eth.getBalance(address, 'latest', function (error, result) {
            if (error) {
                reject(error);
            } else {
                resolve(result);
            }
        })
    })
}

function getBytes(str) {
    return web3.fromAscii(str)
}

contract('Bet', accounts => {
    // account[0] points to the owner on the testRPC setup
    var owner = accounts[0]
    var dealer = accounts[1]
    var user1 = accounts[2]
    var user2 = accounts[3]
    var user3 = accounts[4]

    let betBase
    let betHelper
    let betAddr
    let totalBetAmount = 0
    const minimum_bet = 5e16
    const leftOdds = 250
    const middleOdds = 175
    const rightOdds = 120
    // const deposit = 1e18
    const deposit = 1.25e17
    let startTime = web3.eth.getBlock(web3.eth.blockNumber).timestamp + 60
    console.info('startTime:', startTime)
    const params = [getBytes('NBA'), 0, 1, leftOdds, middleOdds, rightOdds, minimum_bet, startTime]

    const testAmount = 1e17

    before(() => {
        return BetHelper.deployed({from: owner})
            .then(instance => {
                betHelper = instance
                return betHelper.createBet(...params, {gas: 4300000, from: dealer, value: deposit})
            })
            .then(events => {
                betAddr = events.logs[0].args.bet
                console.log('bet address', betAddr)
                betBase = BetBase.at(betAddr)
            })
    })

    it('test getter', async () => {
        const betInfo = await betBase.getBetInfo()
        console.log('betInfo:\n', betInfo)
        const mutableData = await betBase.getBetMutableData()
        console.log('mutable data:', mutableData)
    })

/*    it('test place bet', async function () {
        const betAmount = 1e17
        const choice = 1
        const player = user1
        const info = await betBase.placeBet(choice, {from:player, value:betAmount})
        console.info('logs:', info.logs[0].args)
        const _totalBetAmount = await betBase.amounts(0)
        const playerInfo = await betBase.playerInfo(player)

        totalBetAmount += betAmount
        assert.equal(info.logs[0].args.addr, player)
        assert.equal(info.logs[0].args.choice, choice)
        assert.equal(info.logs[0].args.betAmount, betAmount)
        assert.equal(playerInfo[0], betAmount)
        assert.equal(playerInfo[1], choice)
        assert.equal(totalBetAmount, _totalBetAmount)

    })*/

    it('test place bet choice i odds is too large that dealer is insolvent', async () => {
        const betAmount = 1e18
        const choice = 1
        await assertRevert(betBase.placeBet(choice, {from: user1, value: betAmount}))
    })

    it('test another user place betBase', async () => {
        const choice = 2
        const addr = user2
        const tx = await betBase.placeBet(choice, {from: addr, value: testAmount})
        const _totalBetAmount = await betBase.amounts(0)
        const playerInfo = await betBase.playerInfo(addr)

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
        const tx = await betBase.placeBet(choice, {from: addr, value: testAmount})
        const _totalBetAmount = await betBase.amounts(0)
        const playerInfo = await betBase.playerInfo(addr)

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
        const tx = await betBase.placeBet(choice, {from: user1, value: testAmount})
        const _totalBetAmount = await betBase.amounts(0)
        const playerInfo = await betBase.playerInfo(addr)

        totalBetAmount += testAmount
        assert.equal(tx.logs[0].args.addr, addr)
        assert.equal(tx.logs[0].args.choice, choice)
        assert.equal(playerInfo[0].toNumber(), testAmount)
        assert.equal(playerInfo[1].toNumber(), choice)
        assert.equal(_totalBetAmount.toNumber(), totalBetAmount)
    })

    it('test recharge deposit', async () => {
        const chargeValue = 1e18
        const oldDeposit = (await betBase.deposit()).toNumber()
        const tx = await betBase.rechargeDeposit({from: dealer, value: chargeValue})
        const newDeposit = (await betBase.deposit()).toNumber()

        assert.equal(oldDeposit + chargeValue, newDeposit)
    })

    it('test multi place bet', async () => {
        let choice = 1
        for (let i = 5; i < 10; i++) {
            choice = Math.ceil(Math.random() * 3)
            await betBase.placeBet(choice, {from: accounts[i], value: testAmount})
        }
    })

/*    it('test manual close bet', async () => {
        await setTimestamp(startTime + 1)
        web3.eth.getBalance(user1, function (err, data) {
            console.log('old balance: ', data.toNumber())
        })
        const dealerB = await getBalance(dealer)
        const _lp = 118
        const _rp = 118
        // const _rp = 109
        const tx = await betBase.manualCloseBet(_lp, _rp, {from: owner})
        tx.logs.forEach(l => {
         console.log(l.args)
        })
        const withdrawAmount = (tx.logs[tx.logs.length - 3].args.withdrawAmount).toNumber()
        console.log('remain balance is: ', withdrawAmount)
        console.log('=======================Winner number is: ', tx.logs.length - 3)
        const choice = await betBase.winChoice()
        const lp = await betBase.leftPts()
        const rp = await betBase.rightPts()
        console.log('win choice: ', choice.toNumber())
        web3.eth.getBalance(user1, function (err, data) {
            console.log('new balance: ', data.toNumber())
        })
        assert.equal(lp.toNumber(), _lp)
        assert.equal(rp.toNumber(), _rp)

        const _dealerB = await getBalance(dealer)
        assert.equal(dealerB.add(withdrawAmount).toNumber(), _dealerB.toNumber())
    })

    it('test manual close bet again', async () => {
        const _lp = 118
        const _rp = 109
        await assertRevert(betBase.manualCloseBet(_lp, _rp, {from: owner}))
    })*/

    it('test close bet', async () => {
        await setTimestamp(startTime + 1)
        const winChoice = 3
        const dealerBB = (await getBalance(dealer)).toNumber()
        const tx = await betBase.closeBet(winChoice, {from: owner})
        const withdrowAmount = tx.logs[tx.logs.length - 3].args.withdrawAmount.toNumber()
        const _dealer = tx.logs[tx.logs.length - 3].args.addr
        const _winChoice = await betBase.winChoice()
        const dealerBA = (await getBalance(dealer)).toNumber()

        assert.equal(_dealer, dealer)
        assert.equal(_winChoice, winChoice)
        assert.equal(dealerBA, dealerBB + withdrowAmount)

    })

    it('test close bet after bet closed', async () => {
        await setTimestamp(startTime + 10)
        await assertRevert(betBase.closeBet(3, {from: owner}))
    })

/*    it('test refund', async () => {
        const dealerB = await getBalance(dealer)
        const user1B = await getBalance(user1)
        const tx = await betBase.refund({from: owner});
        const remainB = tx.logs[tx.logs.length - 2].args.withdrawAmount.toNumber()
        console.log('refund remain balance is: ', remainB)
        const _user1B = await getBalance(user1)
        const _dealerB = await getBalance(dealer)

        assert.equal(user1B.add(testAmount).toNumber(), _user1B.toNumber())
        assert.equal(dealerB.add(remainB).toNumber(), _dealerB.toNumber())
    })*/

    after(async () => {
        const choice = await betBase.winChoice()
        const _totalBetAmount = await betBase.amounts(0)
        const _deposit = await betBase.deposit()
        console.log("The winner's choice is:", choice.toNumber())
        console.log('Total bet amount is:', _totalBetAmount.toNumber())
        console.log('Deposit amount is:', _deposit.toNumber())
    })
})
