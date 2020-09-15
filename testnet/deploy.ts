import { Framework } from '@vechain/connex-framework'
import { Driver, SimpleNet, SimpleWallet } from '@vechain/connex-driver'
import { utils, connexutils } from 'myvetools'

import fs = require('fs')

import {
    accounts,
    binVoteCreator, abiVoteCreator,
    binVotingContract, abiVotingContract,
    infoFile
} from './init'

(async () => {
    const wallet = new SimpleWallet()
    wallet.import(accounts[0].privKey)

    const driver = await Driver.connect(new SimpleNet('https://sync-testnet.vechain.org/'), wallet)
    const connex = new Framework(driver)

    let resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVoteCreator, utils.getABI(abiVoteCreator, '', 'constructor')
    )

    let rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addr1 = rec.outputs[0].contractAddress
    console.log('VoteCreator deployed:')
    console.log('\tat: ', addr1)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    resp = await connexutils.deployContract(
        connex, accounts[0].pubKey, 10000000, '0x0',
        binVotingContract, utils.getABI(abiVotingContract, '', 'constructor'),
        addr1
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    const addr2 = rec.outputs[0].contractAddress
    console.log('VotingContract deployed:')
    console.log('\tat: ', addr2)
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    // Call VoteCreator.setVotingContract
    resp = await connexutils.contractCallWithTx(
        connex, accounts[0].pubKey, 300000,
        addr1, '0x0',
        utils.getABI(abiVoteCreator, 'setVotingContract', 'function'),
        addr2
    )
    rec = await connexutils.getReceipt(connex, 5, resp.txid)
    console.log('Call VoteCreate.setVotingContract')
    console.log('\tby: ', resp.signer)
    console.log('\ttxid: ', resp.txid)
    console.log('\tgas used:', rec.gasUsed)

    fs.writeFileSync(infoFile, JSON.stringify({
        addrVoteCreator: addr1,
        addrVotingContract: addr2
    }))
})()
