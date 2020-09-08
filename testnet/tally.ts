import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet, options } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

const fs = require('fs')

import { pre } from '../utils'

import {
    accounts,
    abiVotingContract,
    infoFile,
    tallyRes, invalidBallots
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const auth = accounts[0].pubKey
    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract = info.addrVotingContract
    const voteID = info.voteID

    // Start tally, VotingContract no longer accept new ballots
    let resp = await connexutils.contractCallWithTx(
        connex, auth, 100000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'beginTally', 'function'),
        voteID
    )
    let rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log('Tally starts:')
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // The authority will off-chain download and validate all the ballots
    // and tally and upload the result that can be verified by anyone.
    const r = prepTallyRes(tallyRes)
    resp = await connexutils.contractCallWithTx(
        connex, auth, 1000000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'setTallyRes', 'function'),
        voteID,
        invalidBallots,
        r.v, r.x, r.y, r.proof, r.prefix
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log('Tally result uploaded:')
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // Tally ends
    resp = await connexutils.contractCallWithTx(
        connex, auth, 100000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'endTally', 'function'),
        voteID
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log('Tally ends:')
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)
})()

function prepTallyRes(r: any): any {
    const p = r.proof

    let prefix: string = '0x'
    prefix += pre(r.xy)
    prefix += pre(r.yy)
    prefix += pre(p.hy)
    prefix += pre(p.ty)

    return {
        v: r.v,
        x: r.xx,
        y: r.yx,
        proof: [p.hx, p.tx, p.r],
        prefix: prefix
    }
}