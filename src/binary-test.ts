import assert = require('assert')

import { compressBallot, uncompressBallot, generateBallot, verifyBallot } from './binary-ballot'
import { randPower, randAddress } from './utils'
import { point, uncompress, compress, g, toHex } from './ec'

(() => {
    TestCompressUncompressEC()
    TestCompressUncompressBinaryBallot()
})()

function TestCompressUncompressEC() {
    const cg = compress(g)
    const ug = uncompress(cg.x, cg.pre)
    assert.ok(ug.eq(g))
}

function TestCompressUncompressBinaryBallot() {
    const a = randPower()
    const k = randPower()
    const address = randAddress()
    const gk = g.mul(k)

    const b = generateBallot({a: a, gk: gk, address: address, v: true})
    assert.ok(verifyBallot(b))

    const cb = compressBallot(b)

    const _b = uncompressBallot(cb, address, gk)
    assert.ok(verifyBallot(_b))

    const _cb = compressBallot(_b)

    assert.deepEqual(cb, _cb)
}