import BN from 'bn.js'

const _a = new BN('ffffffff00000001000000000000000000000000fffffffffffffffffffffffc', 16)
const _b = new BN('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', 16)
const _p = new BN('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', 16)

function _expMod(a: BN, b: BN, n: BN): BN {
    a = a.mod(n)
    let result = new BN(1)
    let x = a.clone()

    while (!b.isZero()) {
        const leastSignificantBit = b.mod(new BN(2))
        b = b.div(new BN(2))

        if (!leastSignificantBit.isZero()) {
            result = result.mul(x).mod(n)
        }

        x = x.mul(x).mod(n)
    }
    return result
}

function _deriveY(x: BN, prefix: BN) {
    let y = _expMod(x, new BN(3), _p)
    y = y.add(x.mul(_a).mod(_p)).mod(_p)
    y = y.add(_b).mod(_p)

    y = _expMod(y, _p.add(new BN(1)).div(new BN(4)), _p)

    return y.add(new BN(prefix)).mod(new BN(2)).isZero() ? y : _p.sub(y)
}

interface rawBallot {
    h: BN,
    y: BN,
    proof: BN[],
    prefix: BN
}

export function rawToNormBallot(raw: rawBallot): any {
    const prefix = raw.prefix.toBuffer('be')
    const proof = {
        d1: '0x' + raw.proof[0].toString(16, 64),
        r1: '0x' + raw.proof[1].toString(16, 64),
        d2: '0x' + raw.proof[2].toString(16, 64),
        r2: '0x' + raw.proof[3].toString(16, 64),
        a1x: '0x' + raw.proof[4].toString(16, 64),
        a1y: '0x' + _deriveY(raw.proof[4], new BN(prefix[2])).toString(16, 64),
        b1x: '0x' + raw.proof[5].toString(16, 64),
        b1y: '0x' + _deriveY(raw.proof[5], new BN(prefix[3])).toString(16, 64),
        a2x: '0x' + raw.proof[6].toString(16, 64),
        a2y: '0x' + _deriveY(raw.proof[6], new BN(prefix[4])).toString(16, 64),
        b2x: '0x' + raw.proof[7].toString(16, 64),
        b2y: '0x' + _deriveY(raw.proof[7], new BN(prefix[5])).toString(16, 64)
    }
    return {
        hx: '0x' + raw.h.toString(16, 64),
        hy: '0x' + _deriveY(raw.h, new BN(prefix[0])).toString(16, 64),
        yx: '0x' + raw.y.toString(16, 64),
        yy: '0x' + _deriveY(raw.y, new BN(prefix[1])).toString(16, 64),
        proof: proof
    }
}

export function pre(s: string): string {
    const v = parseInt(s.charAt(s.length - 1), 16)
    return v % 2 == 0 ? '02' : '03'
}