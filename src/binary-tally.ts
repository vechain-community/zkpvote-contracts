import BN from 'bn.js'

import { ECP, g, inv, toHex } from './ec'
import { isValidPower, pre } from './utils'
import { Ballot, verifyBallot } from './binary-ballot'
import { Proof, prove } from './zkp-fiat-shamir'
import { isAddress } from 'myvetools/dist/utils'
import { invalidBallots } from '../testnet/init'
import { verify } from './zkp-fiat-shamir'

type Res = {
    V: number,
    X: ECP,
    Y: ECP,
    proof: Proof,
    invalidBallots: string[]
    total: number
}

export class Tally {
    k: BN
    address: string

    invalids: string[]
    invalidSet: Set<string>
    validSet: Set<string>

    H: ECP
    Y: ECP

    constructor(k: BN, address: string) {
        if (!isValidPower(k)) {
            throw new Error('Invalid private key')
        }

        if (!isAddress(address)) {
            throw new Error('Invalid account address')
        }

        this.k = k
        this.address = address
    }

    count(b: Ballot) {
        const addr = b.proof.address
        if (!isAddress(addr)) {
            throw new Error('Invalid account address')
        }

        if (this.invalidSet.has(addr) || this.validSet.has(addr)) {
            return
        }

        if (verifyBallot(b)) {
            if (typeof this.H === 'undefined') {
                this.H = b.h
                this.Y = b.y
            } else {
                this.H = this.H.add(b.h)
                this.Y = this.Y.add(b.y)
            }

            this.validSet.add(b.proof.address)
        } else {
            this.invalidSet.add(b.proof.address)
            this.invalids.push(addr)
        }
    }

    getRes(): Res {
        // X = H^k
        const X = this.H.mul(this.k)

        // Generate Proof of k
        const proof: Proof = prove({
            address: this.address,
            h: this.H,
            y: X,
            x: this.k
        })

        // Compute the number of yes votes, V
        let V = 0
        const nValidBallot = this.validSet.size
        if (!X.eq(this.Y)) { // only run the loop if there is at least one yes vote
            // g^v = Y/X
            const gV = this.Y.add(inv(X))

            for (V = 1; V <= nValidBallot; V++) {
                if (gV.eq(g.mul(new BN(V)))) {
                    break
                }
            }
        }

        return {
            V: V,
            X: X,
            Y: this.Y,
            proof: proof,
            invalidBallots: this.invalids,
            total: this.validSet.size + this.invalidSet.size
        }
    }
}

export function verifyTallyRes(r: Res): boolean {
    // Check range of V
    if (r.V < 0 || r.V > r.total - invalidBallots.length) {
        return false
    }

    // Check Y == X * g^V
    if (!r.Y.eq(r.X.add(g.mul(new BN(r.V))))) {
        return false
    }

    // Check X, Y on curve
    if (!r.X.validate() || !r.Y.validate()) {
        return false
    }

    // Verify FS zkp
    if (!verify(r.proof)) {
        return false
    }

    return true
}

type ResForTally = {
    V: number,
    X: string,
    Y: string,
    zkp: string[],
    prefix: string
}

export function prepTallyRes(res: Res): ResForTally {
    const { V, X, Y, proof } = res
    const { h, t, r } = proof

    let prefix: string = '0x'
    prefix += pre(toHex(X, 'y'))
    prefix += pre(toHex(Y, 'y'))
    prefix += pre(toHex(h, 'y'))
    prefix += pre(toHex(t, 'y'))

    return {
        V: V,
        X: toHex(X, 'x'),
        Y: toHex(Y, 'x'),
        zkp: [
            toHex(h, 'x'),
            toHex(t, 'x'),
            '0x' + r.toString(16, 32)
        ],
        prefix: prefix
    }
}