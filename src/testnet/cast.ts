import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet, options } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'
import { pre } from '../utils'

const fs = require('fs')

import {
    accounts,
    abiVotingContract,
    infoFile,
    ballots
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    for (let i = 1; i < accounts.length; i++) {
        wallet.import(accounts[i].privKey)
    }

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract = info.addrVotingContract
    const voteID = info.voteID

    /////////////////////////////////////////////////////////////////
    // Cast ballots
    //
    // Ballots are generated off-chain. There are in total 9 ballots 
    // generated for this demo. The first 6 are valid while the last
    // 3 are invalid. They will be cast by accounts[1:9].
    /////////////////////////////////////////////////////////////////
    for (let i = 0; i < ballots.length; i++) {
        const b = prepBallotCast(ballots[i])
        connexutils.contractCallWithTx(
            connex, accounts[i + 1].pubKey, 1000000,
            addrVotingContract, '0x0',
            utils.getABI(abiVotingContract, 'cast', 'function'),
            voteID, b.h, b.y, b.zkp, b.prefix
        )
            .then(resp => {
                connexutils.getReceipt(connex, 5, resp.txid)
                    .then((rec) => {
                        console.log('Cast ballot:')
                        console.log('\ttxid: ', resp.txid)
                        console.log('\tby: ', resp.signer)
                        console.log('\tgas used:', rec.gasUsed)
                    })
                    .catch(err => {
                        console.log('Failed to cast ballot ', i + 1)
                    })
            })
    }

})()

function prepBallotCast(b: any): any {
    const p = b.proof

    let prefix: string = '0x'
    prefix += pre(b.hy)
    prefix += pre(b.yy)
    prefix += pre(p.a1y)
    prefix += pre(p.b1y)
    prefix += pre(p.a2y)
    prefix += pre(p.b2y)

    return {
        h: b.hx,
        y: b.yx,
        zkp: [p.d1, p.r1, p.d2, p.r2, p.a1x, p.b1x, p.a2x, p.b2x],
        prefix: prefix
    }
}