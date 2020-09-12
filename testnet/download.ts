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
import { rawToNormBallot, pre } from './utils'

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
            utils.getABI(abiVotingContract, 'getVoter', 'function'),
            voteID, i
        )
        const addr = out.decoded[0]

        out = await connexutils.contractCall(
            connex, addrVotingContract,
            utils.getABI(abiVotingContract, 'getBallot', 'function'),
            voteID, addr
        )

        const raw = {
            h: new BN(out.decoded[0]),
            y: new BN(out.decoded[1]),
            proof: [
                new BN(out.decoded[2][0]),
                new BN(out.decoded[2][1]),
                new BN(out.decoded[2][2]),
                new BN(out.decoded[2][3]),
                new BN(out.decoded[2][4]),
                new BN(out.decoded[2][5]),
                new BN(out.decoded[2][6]),
                new BN(out.decoded[2][7]),
            ],
            prefix: new BN(out.decoded[3])
        }

        let ballot = rawToNormBallot(raw)
        ballot.proof.data = addr
        ballot.proof.gkx = authPubKey.gkx
        ballot.proof.gky = authPubKey.gky

        dl.push(ballot)
    }

    fs.writeFileSync('./test/data/dl-bin-ballot.json', JSON.stringify(dl))
})()