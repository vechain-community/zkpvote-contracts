import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import fs = require('fs')

import {
    accounts,
    binVotingContract, abiVotingContract,
    binVoteLib, abiVoteLib,
    infoFile
} from './initV2'

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)
    let resp: Connex.Vendor.TxResponse, rec: Connex.Thor.Receipt

    // Deploy binary vote library
    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0', binVoteLib
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addrLib = rec.outputs[0].contractAddress
    console.log('Lib deployed:')
    console.log('\tat: ', addrLib)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // deploy binary voting contract
    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVotingContract, utils.getABI(abiVotingContract, '', 'constructor'),
        addrLib
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addrVoting = rec.outputs[0].contractAddress
    console.log('VotingContract deployed:')
    console.log('\tat: ', addrVoting)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    fs.writeFileSync(infoFile, JSON.stringify({
        addrLib: addrLib,
        addrVotingContract: addrVoting
    }))

    process.exit()
})()
