const votingContract = artifacts.require('VotingContractV2')

const pre = require('../dist/testnetV2/utils').pre
const utils = require('../dist/src/utils')
const ec = require('../dist/src/ec')
const randomBytes = require('crypto').randomBytes
const bb = require('../dist/src/binary-ballot')
const BN = require('bn.js')
const Tally = require('../dist/src/binary-tally').Tally
const prepTallyRes = require('../dist/src/binary-tally').prepTallyRes

// import { pre } from '../testnetV2/utils'
// import { randPower, toHex as toHexBN } from '../src/utils'
// import { toHex as toHexEC, g } from '../src/ec'
// import { randomBytes } from 'crypto'
// import BN from 'bn.js'
// import { point } from '../src/ec'
// import { Ballot, generateBallot, compressBallot } from '../src/binary-ballot'
// import { Tally, prepTallyRes } from '../src/binary-tally'

contract('V2', async (accounts) => {
    it('test1', async () => {
        const inst = await votingContract.deployed()
        const auth = accounts[0]
        const castPeriod = 3

        const topic = '0x' + randomBytes(32).toString('hex')
        const optYes = '0x' + randomBytes(32).toString('hex')
        const optNo = '0x' + randomBytes(32).toString('hex')
        const endTime = Math.round((new Date()).getTime() / 1000) + castPeriod

        // console.log(`topic = ${topic}`)
        // console.log(`optYes = ${optYes}`)
        // console.log(`optNo = ${optNo}`)
        console.log(`endTime = ${endTime}`)

        let tx = await inst.newBinaryVote(
            endTime, topic, optYes, optNo,
            { from: auth }
        )
        assert.equal(tx.receipt.status, true)
        const voteID = tx.logs[0].args.id
        console.log(`voteID = ${voteID}`)

        const topic1 = await inst.topics(voteID)
        assert.equal(topic, topic1)
        const optYes1 = await inst.optYes(voteID)
        assert.equal(optYes, optYes1)
        const optNo1 = await inst.optNo(voteID)
        assert.equal(optNo, optNo1)
        const endTime1 = await inst.castEndTime(voteID)
        assert.equal(endTime, endTime1)

        // Set authority public key
        const k = utils.randPower()
        const gk = ec.g.mul(k)
        const gkx = ec.toHex(gk, 'x')
        const gky = ec.toHex(gk, 'y')
        tx = await inst.setAuthPubKey(voteID, gkx, '0x' + pre(gky), { from: auth })
        assert.equal(tx.receipt.status, true)

        let b = randBallot(gkx, gky, accounts[1])
        let cb = bb.compressBallot(b)
        tx = await inst.cast(voteID, cb.h, cb.y, cb.zkp, cb.prefix, { from: accounts[1] })
        assert.equal(tx.receipt.status, true)

        await new Promise(resolve => setTimeout(resolve, 5 * 1000));

        // Create tally
        const tally = new Tally(k, auth)
        tally.count(b)
        const r = prepTallyRes(tally.getRes(), { from: auth })
        tx = await inst.setTallyRes(
            voteID,
            r.invalidBallots,
            r.V, r.X, r.Y, r.zkp, r.prefix
        )
        assert.equal(tx.receipt.status, true)

        tx = await inst.endTally(voteID, { from: auth })
        assert.equal(tx.receipt.status, true)
    })
})

function randBallot(gkx, gky, acc) {
    const a = utils.randPower() // generate private key, a
    const gk = ec.point(new BN(gkx.slice(2), 'hex'), new BN(gky.slice(2), 'hex'))
    return bb.generateBallot({ a: a, gk: gk, v: true, address: acc })
}