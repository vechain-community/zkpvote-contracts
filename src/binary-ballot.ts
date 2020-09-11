import BN from 'bn.js'

import { prove, Proof, verify } from './zkp-binary-value'
import { ECP, g } from './common'

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