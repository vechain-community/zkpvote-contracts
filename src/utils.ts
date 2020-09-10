import { randomBytes } from 'crypto'
import BN from 'bn.js'

const A = new BN('ffffffff00000001000000000000000000000000fffffffffffffffffffffffc', 16)
const B = new BN('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', 16)
const P = new BN('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', 16)
const N = Buffer.from('ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551', 'hex');
const ZERO = Buffer.alloc(32, 0)

function isValidPower(p: Buffer): boolean {
    return Buffer.isBuffer(p) &&
        p.length === 32 &&
        !p.equals(ZERO) &&
        p.compare(N) < 0
}

/**
 * Randomly sample an integer that is within range (1, p256.N)
 */
export function randPower(): BN {
    for (; ;) {
        const n = randomBytes(32)
        if (isValidPower(n)) {
            return new BN(n)
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