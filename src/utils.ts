import { randomBytes } from 'crypto'
import BN from 'bn.js'

import {a as A, b as B, p as P, n as N, ECP, point} from './common'

export function isValidPower(x: BN): boolean {
    return x.gt(new BN(0)) && x.lt(N)
}

export function randPower(): BN {
    for (; ;) {
        const x = new BN(randomBytes(32))
        if (isValidPower(x)) {
            return x
        }
    }
}

/**
 * Compute b^p mod n
 * @param b base
 * @param p power
 * @param n modulus
 */
function expMod(b: BN, p: BN, n: BN): BN {
    b = b.mod(n)
    let result = new BN(1)
    let x = b.clone()

    while (!p.isZero()) {
        const leastSignificantBit = p.mod(new BN(2))
        p = p.div(new BN(2))

        if (!leastSignificantBit.isZero()) {
            result = result.mul(x).mod(n)
        }

        x = x.mul(x).mod(n)
    }
    return result
}

/**
 * Compute y coordinate of an EC point given the x coordinate and 
 * parity of the y coordinate.
 * @param x x coordinate 
 * @param prefix even - 0x02; odd - 0x03 
 */
export function deriveY(x: BN, prefix: BN): BN {
    let y = expMod(x, new BN(3), P)
    y = y.add(x.mul(A).mod(P)).mod(P)
    y = y.add(B).mod(P)

    y = expMod(y, P.add(new BN(1)).div(new BN(4)), P)

    return y.add(new BN(prefix)).mod(new BN(2)).isZero() ? y : P.sub(y)
}

export function pre(s: string, t: 'string' | 'number'): string | number {
    const v = parseInt(s.charAt(s.length - 1), 16)
    if (t === 'string') {
        return v % 2 == 0 ? '02' : '03'
    }
    return v % 2 == 0 ? 2 : 3
}

export function ecInv(x: ECP): ECP {
    return point(
        x.getX(),
        P.sub(x.getY())
    )
}