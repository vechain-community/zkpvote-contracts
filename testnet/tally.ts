import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import fs = require('fs')
import BN from 'bn.js'

import { pre } from './utils'
import { toHex } from '../src/utils'
import { CompressedBallot, uncompressBallot } from '../src/binary-ballot'
import { Tally, prepTallyRes } from '../src/binary-tally'
import { g } from '../src/ec'

import {
    accounts,
    abiVotingContract,
    infoFile
} from './init'


function getCompressedBallot(out: Connex.Thor.VMOutput): CompressedBallot {
    return {
        h: toHex(out.decoded[0], 10),
        y: toHex(out.decoded[1], 10),
        zkp: [
            toHex(out.decoded[2][0], 10),
            toHex(out.decoded[2][1], 10),
            toHex(out.decoded[2][2], 10),
            toHex(out.decoded[2][3], 10),
            toHex(out.decoded[2][4], 10),
            toHex(out.decoded[2][5], 10),
            toHex(out.decoded[2][6], 10),
            toHex(out.decoded[2][7], 10),
        ],
        prefix: toHex(out.decoded[3], 10)
    }
}

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const auth = accounts[0].pubKey
    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract = info.addrVotingContract
    const voteID = info.voteID

    let resp: Connex.Vendor.TxResponse, rec: Connex.Thor.Receipt

    // Start tally, VotingContract no longer accept new ballots
    resp = await connexutils.contractCallWithTx(
        connex, auth, 100000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'beginTally', 'function'),
        voteID
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log(`Tally starts:
    txid: ${resp.txid}
    gas used: ${rec.gasUsed}`)

    /**
     * The authority will off-chain download and validate all the ballots
     * and tally and upload the result that can be verified by anyone.
     */
    
    // Get the number of voter
    let out = await connexutils.contractCall(
        connex, addrVotingContract,
        utils.getABI(abiVotingContract, 'getNumVoter', 'function'),
        voteID
    )
    const n = parseInt(out.decoded[0])

    // Prepare authority public and private keys
    const k = new BN(info.k.slice(2), 'hex')
    const gk = g.mul(k)

    // New tally
    const tally = new Tally(k, auth)

    // Download, uncompress and count ballot
    for (let i = 0; i < n; i++) {
        // Get the address of the account that cast a ballot
        out = await connexutils.contractCall(
            connex, addrVotingContract,
            utils.getABI(abiVotingContract, 'getVoter', 'function'),
            voteID, i
        )
        const addr = out.decoded[0]

        // download compressed ballot
        out = await connexutils.contractCall(
            connex, addrVotingContract,
            utils.getABI(abiVotingContract, 'getBallot', 'function'),
            voteID, addr
        )
        const cb = getCompressedBallot(out)
        
        const b = uncompressBallot(cb, addr, gk)

        tally.count(b)
    }

    const r = prepTallyRes(tally.getRes())

    // Submit tally result
    resp = await connexutils.contractCallWithTx(
        connex, auth, 1000000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'setTallyRes', 'function'),
        voteID,
        r.invalidBallots,
        r.V, r.X, r.Y, r.zkp, r.prefix
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log(`Tally result submitted:
    txid: ${resp.txid}
    gas used: ${rec.gasUsed}`)

    // Tally ends
    resp = await connexutils.contractCallWithTx(
        connex, auth, 100000,
        addrVotingContract, '0x0',
        utils.getABI(abiVotingContract, 'endTally', 'function'),
        voteID
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log(`Tally ends:
    txid: ${resp.txid}
    gas used: ${rec.gasUsed}`)

    process.exit()
})()