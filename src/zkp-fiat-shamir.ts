import BN from 'bn.js'
import hash = require('hash.js')

import { ECP, n } from './common'
import { randPower, isValidPower } from './utils'
import { isAddress } from 'myvetools/dist/utils'

type Prover = {
    x: BN,
    h: ECP,
    y: ECP, // y = h^x
    address: string
}

type Proof = {
    address: string,
    h: ECP,
    y: ECP,
    t: ECP,
    r: BN
}

export function prove(p: Prover): Proof {
    const {address, x, h, y} = p

    if (!isAddress(address)) {
        throw new Error('Invalid address')
    }

    if (!isValidPower(x)) {
        throw new Error('Invalid private key')
    }

    if (!h.validate()) {
        throw new Error('Invalid base h')
    }

    if (!y.validate() || !y.eq(h.mul(x))) {
        throw new Error('Invalid exp y')
    }

    const v = randPower()

    // t = h^v
    const t = h.mul(v)

    // c = H(address, h, y, t)
    const c = new BN(
        hash.sha256()
            .update(address.slice(2))
            .update(h.getX().toString(16, 32)).update(h.getY().toString(16, 32))
            .update(y.getX().toString(16, 32)).update(y.getY().toString(16, 32))
            .update(t.getX().toString(16, 32)).update(t.getY().toString(16, 32))
            .digest('hex'),
        'hex'
    )

    // r = v - c*x
    const r = v.sub(c.mul(x).umod(n)).umod(n)

    return {
        address: address,
        h: h,
        y: y,
        t: t,
        r: r
    }
}

export function verify(p: Proof): boolean {
    const {address, h, y, t, r} = p

    if (!isAddress(address)) {
        return false
    }

    if (!isValidPower(r)) {
        return false
    }

    if (!h.validate() || !y.validate() || !t.validate()) {
        return false
    }

    const c = new BN(
        hash.sha256()
            .update(address.slice(2))
            .update(h.getX().toString(16, 32)).update(h.getY().toString(16, 32))
            .update(y.getX().toString(16, 32)).update(y.getY().toString(16, 32))
            .update(t.getX().toString(16, 32)).update(t.getY().toString(16, 32))
            .digest('hex'),
        'hex'
    )

    //t == (h^r)(y^c)
    if (!t.eq(h.mul(r).add(y.mul(c)))) {
        return false
    }

    return true
}