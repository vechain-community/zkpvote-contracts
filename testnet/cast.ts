import fs = require('fs')
import BN from 'bn.js'

import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import { randPower } from '../src/utils'
import { point, n } from '../src/ec'
import { generateBallot, compressBallot, verifyBallot } from '../src/binary-ballot'
// import { pre } from './utils'

import {
    accounts,
    abiVotingContract,
    infoFile
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    for (let i = 1; i < accounts.length; i++) {
        wallet.import(accounts[i].privKey)
    }

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract: string = info.addrVotingContract
    const voteID: string = info.voteID
    const gkx: string = info.gkx
    const gky: string = info.gky

    /////////////////////////////////////////////////////////////////
    // Cast ballots
    //
    // Ballots are generated off-chain. There are in total 9 ballots 
    // generated for this demo. The first 6 are valid while the last
    // 3 are invalid. They will be cast by accounts[1:9].
    /////////////////////////////////////////////////////////////////
    for (let i = 1; i < accounts.length; i++) {
        // Prepare ballot
        const a = randPower() // generate private key, a
        const gk = point(new BN(gkx.slice(2), 'hex'), new BN(gky.slice(2), 'hex'))
        const address = accounts[i].pubKey
        const v = i % 2 == 0

        const ballot = generateBallot({ a: a, gk: gk, v: v, address: address })

        // set d2 = d2 + 1 to invalidate ballot
        if (i > 6) {
            ballot.proof.d1 = ballot.proof.d1.add(new BN(1)).umod(n)
            if (verifyBallot(ballot)) {
                throw new Error(`Ballot ${i} should be invalid`)
            }
        }

        const b = compressBallot(ballot)

        // Cast ballot
        connexutils.contractCallWithTx(
            connex, accounts[i].pubKey, 1000000,
            addrVotingContract, '0x0',
            utils.getABI(abiVotingContract, 'cast', 'function'),
            voteID, b.h, b.y, b.zkp, b.prefix
        )
            .then(resp => {
                connexutils.getReceipt(connex, 5, resp.txid)
                    .then((rec) => {
                        console.log(`Cast ballot ${i}:
    txid: ${resp.txid}
    by: ${resp.signer}
    gas used: ${rec.gasUsed}`)
                        connexutils.contractCall(
                            connex, addrVotingContract,
                            utils.getABI(abiVotingContract, 'verifyBallot', 'function'),
                            voteID, address
                        ).then(out => {
                            if (out.decoded[0] == 0) {
                                console.log(`Invalid ballot ${i}:
    address: ${address}`)
                            }
                        })
                    })
                    .catch(err => {
                        console.log(`Failed to cast ballot ${i + 1}
    Err: ${err}`)
                    })
            })
    }
})()