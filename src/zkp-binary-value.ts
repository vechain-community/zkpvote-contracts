import BN from 'bn.js'
import hash = require('hash.js')

import { ECP, g, n } from './ec'
import { randPower, isValidPower } from './utils'
import { isAddress } from 'myvetools/dist/utils'

export type Proof = {
    address: string,
    ga: ECP,
    gk: ECP,
    y: ECP,
    d1: BN,
    r1: BN,
    d2: BN,
    r2: BN,
    a1: ECP,
    b1: ECP,
    a2: ECP,
    b2: ECP
}

type Prover = {
    a: BN,
    v: boolean,
    address: string
    gk: ECP
}

export function prove(p: Prover): Proof {
    const { a, address, v, gk } = p

    if (!isAddress(address)) {
        throw new Error('Invalid address')
    }

    if (!isValidPower(a)) {
        throw new Error('Invalid private key a')
    }

    if (!gk.validate()) {
        throw new Error('Invalid public key gk')
    }

    const ga: ECP = g.mul(a)

    // console.log(n.toString(16, 32))

    const w = randPower()

    let y: ECP, a1: ECP, b1: ECP, a2: ECP, b2: ECP
    let r1: BN, d1: BN, r2: BN, d2: BN, c: BN

    if (!v) {
        r2 = randPower()
        d2 = randPower()

        // y = g^{k*a}
        y = gk.mul(a)

        // a1 = g^w
        a1 = g.mul(w)

        // // b1 = g^{kw}
        b1 = gk.mul(w)

        // a2 = g^{r2 + d2*a}
        a2 = g.mul(
            r2.add(d2.mul(a).umod(n)).umod(n)
        )

        // b2 = g^{d2*k*a + k*r2 - d2}
        b2 = gk.mul(
            d2.mul(a).umod(n).add(r2).umod(n)
        ).add(g.mul(n.sub(d2)))

        // c = hash(data, g^a, y, a1, b1, a2, b2)
        c = new BN(
            hash.sha256()
                .update(address.slice(2), 'hex')
                .update(ga.getX().toString(16, 32), 'hex').update(ga.getY().toString(16, 32), 'hex')
                .update(y.getX().toString(16, 32), 'hex').update(y.getY().toString(16, 32), 'hex')
                .update(a1.getX().toString(16, 32), 'hex').update(a1.getY().toString(16, 32), 'hex')
                .update(b1.getX().toString(16, 32), 'hex').update(b1.getY().toString(16, 32), 'hex')
                .update(a2.getX().toString(16, 32), 'hex').update(a2.getY().toString(16, 32), 'hex')
                .update(b2.getX().toString(16, 32), 'hex').update(b2.getY().toString(16, 32), 'hex')
                .digest('hex'),
            'hex'
        )

        // d1 = c - d2
        d1 = c.sub(d2)
        d1 = d1.umod(n)

        // r1 = w - d1*a
        r1 = w.sub(d1.mul(a).umod(n)).umod(n)
    } else {
        r1 = randPower()
        d1 = randPower()

        // y = g^{ka+1}
        y = gk.mul(a).add(g)

        // a2 = g^w
        a2 = g.mul(w)

        // b2 = g^{kw}
        b2 = gk.mul(w)

        // a1 = g^{r1 + d1*a}
        a1 = g.mul(
            r1.add(d1.mul(a).umod(n)).umod(n)
        )

        // b1 = g^{d1*k*a + k*r1 + d1}
        b1 = gk.mul(
            d1.mul(a).umod(n).add(r1).umod(n)
        ).add(g.mul(d1))

        // c = hash(data, g^a, y, a1, b1, a2, b2)
        c = new BN(
            hash.sha256()
                .update(address.slice(2), 'hex')
                .update(ga.getX().toString(16, 32), 'hex').update(ga.getY().toString(16, 32), 'hex')
                .update(y.getX().toString(16, 32), 'hex').update(y.getY().toString(16, 32), 'hex')
                .update(a1.getX().toString(16, 32), 'hex').update(a1.getY().toString(16, 32), 'hex')
                .update(b1.getX().toString(16, 32), 'hex').update(b1.getY().toString(16, 32), 'hex')
                .update(a2.getX().toString(16, 32), 'hex').update(a2.getY().toString(16, 32), 'hex')
                .update(b2.getX().toString(16, 32), 'hex').update(b2.getY().toString(16, 32), 'hex')
                .digest('hex'),
            'hex'
        )

        // d2 = c - d1
        d2 = c.sub(d1)
        d2 = d2.umod(n)

        // r2 = w - d2*a
        r2 = w.sub(d2.mul(a).umod(n))
        r2 = r2.umod(n)
    }

    return {
        address: address,
        ga: ga,
        gk: gk,
        y: y,
        d1: d1,
        r1: r1,
        d2: d2,
        r2: r2,
        a1: a1,
        b1: b1,
        a2: a2,
        b2: b2
    }
}

export function verify(p: Proof): boolean {
    const { address, ga, gk, y, d1, r1, d2, r2, a1, b1, a2, b2 } = p

    // check ec points
    if (!y.validate() || !ga.validate() || !gk.validate() ||
        !a1.validate() || !b1.validate() ||
        !a2.validate() || !b2.validate()) {
        return false
    }

    // check d1, r1, d2, r2
    if (!isValidPower(d1) || !isValidPower(r1) ||
        !isValidPower(d2) || !isValidPower(r2)) {
        return false
    }

    if (!isAddress(address)) {
        return false
    }

    // d1 + d2 == c mod N
    const c = new BN(
        hash.sha256()
            .update(address.slice(2), 'hex')
            .update(ga.getX().toString(16, 32), 'hex').update(ga.getY().toString(16, 32), 'hex')
            .update(y.getX().toString(16, 32), 'hex').update(y.getY().toString(16, 32), 'hex')
            .update(a1.getX().toString(16, 32), 'hex').update(a1.getY().toString(16, 32), 'hex')
            .update(b1.getX().toString(16, 32), 'hex').update(b1.getY().toString(16, 32), 'hex')
            .update(a2.getX().toString(16, 32), 'hex').update(a2.getY().toString(16, 32), 'hex')
            .update(b2.getX().toString(16, 32), 'hex').update(b2.getY().toString(16, 32), 'hex')
            .digest('hex'),
        'hex'
    )
    if (!c.eq(d1.add(d2).umod(n))) {
        return false
    }

    // a1 == g^{r1 + d1*a}
    const A1 = g.mul(r1).add(ga.mul(d1))
    if (!A1.eq(a1)) {
        return false
    }

    // b1 == g^{k*r1} y^d1
    const B1 = gk.mul(r1).add(y.mul(d1))
    if (!B1.eq(b1)) {
        return false
    }

    // a2 == g^{r2 + d2*a}
    const A2 = g.mul(r2).add(ga.mul(d2))
    if (!A2.eq(a2)) {
        return false
    }

    return true
}