import BN from 'bn.js'
const curves = require('elliptic').curves

export interface ECP {
    mul(x: BN): ECP;
    add(x: ECP): ECP;

    validate(): boolean;
    eq(x: ECP): boolean;

    getX(): BN;
    getY(): BN;
}

const p256 = curves.p256
export const g: ECP = p256.g
export const n: BN = p256.n

const a = new BN('ffffffff00000001000000000000000000000000fffffffffffffffffffffffc', 16)
const b = new BN('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', 16)
const p = new BN('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', 16)

export function point(x: BN, y: BN): ECP {
    return p256.curve.point(x, y, false)
}

export function inv(x: ECP): ECP {
    return point(
        x.getX(),
        p.sub(x.getY())
    )
}

// a ^ b mod n
function expMod(a: BN, b: BN, n: BN): BN {
    a = a.umod(n)
    let result = new BN(1)
    let x = a.clone()

    while (!b.isZero()) {
        const leastSignificantBit = b.umod(new BN(2))
        b = b.div(new BN(2))

        if (!leastSignificantBit.isZero()) {
            result = result.mul(x).umod(n)
        }

        x = x.mul(x).umod(n)
    }
    return result
}

/**
 * Compute y coordinate of an EC point given the x coordinate and 
 * parity of the y coordinate.
 * @param x x coordinate 
 * @param prefix even - 0x02; odd - 0x03 
 */
function deriveY(x: BN, pre: '02' | '03'): BN {
    let y = expMod(x, new BN(3), p)
    y = y.add(x.mul(a).umod(p)).umod(p)
    y = y.add(b).umod(p)

    y = expMod(y, p.add(new BN(1)).div(new BN(4)), p)

    return y.add(new BN(pre)).isEven() ? y : p.sub(y)
}

export function compress(p: ECP): {x: string, pre: '02' | '03'} {
    if (p.getY().isEven()) {
        return {
            x: toHex(p, 'x'),
            pre: '02'
        }
    }
    return {
        x: toHex(p, 'x'),
        pre: '03'
    }
}

export function uncompress(x: string, pre: '02' | '03'): ECP {
    return point(new BN(x.slice(2), 16), deriveY(new BN(x.slice(2), 16), pre))
}

export function toHex(p: ECP, opt: 'x' | 'y'): string {
    const s = opt === 'x' ? p.getX().toString(16, 32) : p.getY().toString(16, 32)
    return '0x' + s
}