import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import fs = require('fs')

import {
    accounts,
    abiVotingContract,
    infoFile
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    const info = JSON.parse(fs.readFileSync(infoFile, 'utf8'))
    const addrVotingContract = info.addrVotingContract
    const voteID = info.voteID

    // Verify tally result
    let out = await connexutils.contractCall(
        connex, addrVotingContract,
        utils.getABI(abiVotingContract, 'verifyTallyRes', 'function'),
        voteID
    )
    if (out.decoded[0]) {
        console.log('Verify tally result: PASS')
    } else {
        console.log('Verify tally result: FAIL')
    }

    process.exit()
})()