import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet, options } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

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
        const d = prepBallotCast(ballots[i])
        connexutils.contractCallWithTx(
            connex, accounts[i + 1].pubKey, 1000000,
            addrVotingContract, '0x0',
            utils.getABI(abiVotingContract, 'cast', 'function'),
            voteID, d.ga, d.y, d.params, d.a1, d.b1, d.a2, d.b2
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

function prepBallotCast(b: any) {
    const p = b.proof
    return {
        ga: [b.hx, b.hy],
        y: [b.yx, b.yy],
        params: [p.d1, p.r1, p.d2, p.r2],
        a1: [p.a1x, p.a1y],
        b1: [p.b1x, p.b1y],
        a2: [p.a2x, p.a2y],
        b2: [p.b2x, p.b2y]
    }
}