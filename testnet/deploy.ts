import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import fs = require('fs')

import {
    accounts,
    binVoteCreator, abiVoteCreator,
    binVotingContract, abiVotingContract,
    binVoteLib, abiVoteLib,
    infoFile
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)
    let resp: Connex.Vendor.TxResponse, rec: Connex.Thor.Receipt

    // Deploy binary vote library
    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVoteLib, utils.getABI(abiVoteLib, '', 'constructor')
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addrLib = rec.outputs[0].contractAddress
    console.log('Lib deployed:')
    console.log('\tat: ', addrLib)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // deploy binary vote creator
    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVoteCreator, utils.getABI(abiVoteCreator, '', 'constructor'),
        addrLib
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addrCreator = rec.outputs[0].contractAddress
    console.log('VoteCreator deployed:')
    console.log('\tat: ', addrCreator)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // deploy binary voting contract
    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVotingContract, utils.getABI(abiVotingContract, '', 'constructor'),
        addrCreator
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addrVoting = rec.outputs[0].contractAddress
    console.log('VotingContract deployed:')
    console.log('\tat: ', addrVoting)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // Call VoteCreator.setVotingContract
    resp = await connexutils.contractCallWithTx(
        connex, accounts[0].pubKey, 300000,
        addrCreator, '0x0',
        utils.getABI(abiVoteCreator, 'setVotingContract', 'function'),
        addrVoting
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log('Call VoteCreate.setVotingContract')
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    fs.writeFileSync(infoFile, JSON.stringify({
        addrVoteCreator: addrCreator,
        addrVotingContract: addrVoting
    }))

    process.exit()
})()
