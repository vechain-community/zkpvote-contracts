import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet, options } from '@vechain/connex-driver'

const BN = require('bn.js')
const fs = require('fs')

import { utils, connexutils } from 'myvetools'

import {
    abiVotingContract,
    authPubKey,
    infoFile
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract = info.addrVotingContract
    const voteID = info.voteID

    // Get the number of voter
    let out = await connexutils.contractCall(
        connex, addrVotingContract,
        utils.getABI(abiVotingContract, 'getNumVoter', 'function'),
        voteID
    )
    const n = parseInt(out.decoded[0])

    // download ballot
    const dl = []
    for (let i = 0; i < n; i++) {
        out = await connexutils.contractCall(
            connex, addrVotingContract,
            utils.getABI(abiVotingContract, 'getVoter','function'),
            voteID, i
        )
        const addr = out.decoded[0]

        out = await connexutils.contractCall(
            connex, addrVotingContract,
            utils.getABI(abiVotingContract, 'getBallot','function'),
            voteID, addr
        )
        const ballot = {
            hx: toHex(out.decoded[0][0]),
            hy: toHex(out.decoded[0][1]),
            yx: toHex(out.decoded[1][0]),
            yy: toHex(out.decoded[1][1]),
            proof: {
                data: addr,
                gkx: authPubKey.gkx,
                gky: authPubKey.gky,
                d1: toHex(out.decoded[2][0]),
                r1: toHex(out.decoded[2][1]),
                d2: toHex(out.decoded[2][2]),
                r2: toHex(out.decoded[2][3]),
                a1x: toHex(out.decoded[3][0]),
                a1y: toHex(out.decoded[3][1]),
                b1x: toHex(out.decoded[4][0]),
                b1y: toHex(out.decoded[4][1]),
                a2x: toHex(out.decoded[5][0]),
                a2y: toHex(out.decoded[5][1]),
                b2x: toHex(out.decoded[6][0]),
                b2y: toHex(out.decoded[6][1]),
            }
        }
        dl.push(ballot)
    }

    fs.writeFileSync('./test/data/dl-bin-ballot.json', JSON.stringify(dl))
})()

function toHex(numStr: string): string {
    let hexStr = new BN(numStr).toString(16)
    if(hexStr.length % 2 != 0){
        hexStr = '0' + hexStr
    }

    return '0x' + hexStr
}