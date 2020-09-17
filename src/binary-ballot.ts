import BN from 'bn.js'

import { prove, Proof, verify } from './zkp-binary-value'
import { ECP, g, toHex, compress, uncompress } from './ec'
import { toHex as toHexBN } from './utils'

export type Ballot = {
    h: ECP,
    y: ECP,
    proof: Proof
}

export function generateBallot(params: { a: BN, gk: ECP, v: boolean, address: string }): Ballot {
    const { a, gk, v, address } = params

    const h = g.mul(a)
    let y = gk.mul(a)
    if (v) {
        y = y.add(g)
    }
    const proof = prove({
        address: address,
        gk: gk,
        a: a,
        v: v
    })

    return {
        h: h,
        y: y,
        proof: proof
    }
}

export function verifyBallot(b: Ballot): boolean {
    const { h, y, proof } = b

    if (!h.validate() || !y.validate()) {
        return false
    }

    return verify(proof)
}

export type CompressedBallot = {
    h: string,
    y: string,
    zkp: string[],
    prefix: string
}

export function compressBallot(b: Ballot): CompressedBallot {
    const { h, y, proof } = b
    const { d1, r1, d2, r2, a1, b1, a2, b2 } = proof

    let prefix: string = '0x'
    prefix += compress(h).pre
    prefix += compress(y).pre
    prefix += compress(a1).pre
    prefix += compress(b1).pre
    prefix += compress(a2).pre
    prefix += compress(b2).pre

    return {
        h: toHex(h, 'x'),
        y: toHex(y, 'x'),
        zkp: [
            '0x' + d1.toString(16, 32),
            '0x' + r1.toString(16, 32),
            '0x' + d2.toString(16, 32),
            '0x' + r2.toString(16, 32),
            toHex(a1, 'x'),
            toHex(b1, 'x'),
            toHex(a2, 'x'),
            toHex(b2, 'x')
        ],
        prefix: prefix
    }
}

export function uncompressBallot(b: CompressedBallot, address: string, gk: ECP): Ballot {
    const { h, y, zkp, prefix } = b
    let pre: ('02' | '03')[] = []
    const buff = new BN(prefix.slice(2), 16).toBuffer('be')
    buff.forEach((v, i) => {
        if (v == 2) {
            pre[i] = '02'
        } else {
            pre[i] = '03'
        }
    })

    const uy = uncompress(y, pre[1])
    const uh = uncompress(h, pre[0])
    return {
        h: uh,
        y: uy,
        proof: {
            address: address,
            gk: gk,
            ga: uh,
            y: uy,
            d1: new BN(zkp[0].slice(2), 16),
            r1: new BN(zkp[1].slice(2), 16),
            d2: new BN(zkp[2].slice(2), 16),
            r2: new BN(zkp[3].slice(2), 16),
            a1: uncompress(zkp[4], pre[2]),
            b1: uncompress(zkp[5], pre[3]),
            a2: uncompress(zkp[6], pre[4]),
            b2: uncompress(zkp[7], pre[5])
        }
    }
}

export function print(b: Ballot): string {
    return `address: ${b.proof.address}
hx: ${toHex(b.h, 'x')}
hy: ${toHex(b.h, 'y')}
yx: ${toHex(b.y, 'x')}
yy: ${toHex(b.y, 'y')}
gax: ${toHex(b.proof.ga, 'x')}
gay: ${toHex(b.proof.ga, 'y')}
gkx: ${toHex(b.proof.gk, 'x')}
gky: ${toHex(b.proof.gk, 'y')}
a1x: ${toHex(b.proof.a1, 'x')}
a1y: ${toHex(b.proof.a1, 'y')}
b1x: ${toHex(b.proof.b1, 'x')}
b1y: ${toHex(b.proof.b1, 'y')}
a2x: ${toHex(b.proof.a2, 'x')}
a2y: ${toHex(b.proof.a2, 'y')}
b2x: ${toHex(b.proof.b2, 'x')}
b2y: ${toHex(b.proof.b2, 'y')}
d1: ${toHexBN(b.proof.d1)}
r1: ${toHexBN(b.proof.r1)}
d2: ${toHexBN(b.proof.d2)}
r2: ${toHexBN(b.proof.r2)}`
}