import { randomBytes } from 'crypto'
const assert = require('assert').strict
const EC = require('elliptic').ec
import BN from 'bn.js'

import { ECP } from './ec'
import * as BNZKP from './zkp-binary-value'
import * as FSZKP from './zkp-fiat-shamir'

(() => {
    const ec = new EC('p256')

    for (let i = 0; i < 100; i++) {
        const k = ec.genKeyPair()
        const a = ec.genKeyPair()

        // Test zkp of binary value
        const BNProver = {
            address: '0x' + new BN(randomBytes(20)).toString(16, 20),
            v: i % 2 == 0,
            a: new BN(a.getPrivate()),
            gk: k.getPublic()
        }
        const BNProof = BNZKP.prove(BNProver)
        assert.ok(BNZKP.verify(BNProof), `BNZKP test ${i} failed`)

        // Test Fiat-Shamir zkp
        const x: BN = a.getPrivate()
        const h: ECP = a.getPublic()
        const FSProver = {
            address: '0x' + new BN(randomBytes(20)).toString(16, 20),
            x: x,
            h: h,
            y: h.mul(x)
        }
        const FSProof = FSZKP.prove(FSProver)
        assert.ok(FSZKP.verify(FSProof), `FSZKP test ${i} failed`)
    }
})()