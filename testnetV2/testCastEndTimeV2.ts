import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'

import { utils, connexutils } from 'myvetools'

import fs = require('fs')

import {
	accounts,
	abiVotingContract,
	infoFile,
	// contractA, abiA
} from './initV2'

import { pre } from './utils'
import { randPower, toHex as toHexBN } from '../src/utils'
import { toHex as toHexEC, g } from '../src/ec'

import { randomBytes } from 'crypto'
import BN from 'bn.js'

import { point } from '../src/ec'
import { Ballot, generateBallot, compressBallot } from '../src/binary-ballot'

import { Tally, prepTallyRes } from '../src/binary-tally'

(async () => {
	const wallet = new SimpleWallet()
	wallet.import(accounts[0].privKey)

	const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
	const connex = new Framework(driver)

	const auth = accounts[0].pubKey
	const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
	const addrVotingContract = info.addrVotingContract

	const castPeriod = 60 // seconds

	let resp: Connex.Vendor.TxResponse
	let rec: Connex.Thor.Receipt
	let out: Connex.Thor.VMOutput

	// Call VoteCreator.newBinaryVote
	resp = await connexutils.contractCallWithTx(
		connex, auth, 10000000,
		addrVotingContract, '0x0',
		utils.getABI(abiVotingContract, 'newBinaryVote', 'function'),
		Math.round((new Date()).getTime()/1000) + castPeriod,
		'0x' + randomBytes(32).toString('hex'),
		'0x' + randomBytes(32).toString('hex'),
		'0x' + randomBytes(32).toString('hex'),
	)
	rec = await connexutils.getReceipt(connex, 5, resp.txid)
	const voteID = rec.outputs[0].events[0].topics[1]
	console.log(`Vote created:
	at unix time: ${rec.meta.blockTimestamp}
	casting lasts: ${castPeriod} seconds
	voteID: ${voteID}`)

	// Calling VotingContract.setAuthPubKey to set the authority public key
	const k = randPower()
	const gk = g.mul(k)
	const gkx = toHexEC(gk, 'x')
	const gky = toHexEC(gk, 'y')
	resp = await connexutils.contractCallWithTx(
		connex, auth, 300000,
		addrVotingContract, '0x0',
		utils.getABI(abiVotingContract, 'setAuthPubKey', 'function'),
		voteID, gkx, '0x' + pre(gky)
	)
	rec = await connexutils.getReceipt(connex, 5, resp.txid)
	console.log(`Set authority public key:
	at unix time: ${rec.meta.blockTimestamp}`)

	// Cast a ballot within the casting period
	let b = randBallot(gkx, gky, accounts[0].pubKey)
	let cb = compressBallot(b)
	resp = await connexutils.contractCallWithTx(
		connex, auth, 1000000,
		addrVotingContract, '0x0',
		utils.getABI(abiVotingContract, 'cast', 'function'),
		voteID, cb.h, cb.y, cb.zkp, cb.prefix
	)
	rec = await connexutils.getReceipt(connex, 5, resp.txid);
	console.log(`Cast ballot:
	reverted: ${rec.reverted}
	at unix time: ${rec.meta.blockTimestamp}`)

	// Create tally
	const tally = new Tally(k, auth)
	tally.count(b)
	const r = prepTallyRes(tally.getRes())
	resp = await connexutils.contractCallWithTx(
        connex, auth, 1000000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'setTallyRes', 'function'),
        voteID,
        r.invalidBallots,
        r.V, r.X, r.Y, r.zkp, r.prefix
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log(`Tried to submit tally result:
	reverted: ${rec.reverted}
	at unix time: ${rec.meta.blockTimestamp}`)	

	console.log(`Wait for 20 seconds`)
	await new Promise(resolve => setTimeout(resolve, 20*1000)); // millisecond

	// Casting a ballot outside the casting period
	b = randBallot(gkx, gky, accounts[0].pubKey)
	cb = compressBallot(b)
	resp = await connexutils.contractCallWithTx(
		connex, accounts[0].pubKey, 1000000,
		addrVotingContract, '0x0',
		utils.getABI(abiVotingContract, 'cast', 'function'),
		voteID, cb.h, cb.y, cb.zkp, cb.prefix
	)
	rec = await connexutils.getReceipt(connex, 5, resp.txid);
	console.log(`Cast ballot: 
	reverted: ${rec.reverted}
	at unix time: ${rec.meta.blockTimestamp}`)

	resp = await connexutils.contractCallWithTx(
        connex, auth, 1000000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'setTallyRes', 'function'),
        voteID,
        r.invalidBallots,
        r.V, r.X, r.Y, r.zkp, r.prefix
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
	console.log(`Tried to submit tally result:
	reverted: ${rec.reverted}
	at unix time: ${rec.meta.blockTimestamp}`)

	// Tally ends
    resp = await connexutils.contractCallWithTx(
        connex, auth, 100000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'endTally', 'function'),
        voteID
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
	console.log(`Tally ends:
	reverted: ${rec.reverted}
	at unix time: ${rec.meta.blockTimestamp}`)
	
	process.exit()
})()

function randBallot(gkx: string, gky: string, acc: string): Ballot {
	const a = randPower() // generate private key, a
	const gk = point(new BN(gkx.slice(2), 'hex'), new BN(gky.slice(2), 'hex'))
	return generateBallot({ a: a, gk: gk, v: true, address: acc })
}