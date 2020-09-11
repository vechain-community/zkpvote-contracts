import BN from 'bn.js'

import { ECP, g } from './common'
import { ecInv, isValidPower } from './utils'
import { Ballot, verifyBallot } from './binary-ballot'
import { Proof, prove } from './zkp-fiat-shamir'
import { isAddress } from 'myvetools/dist/utils'
import { invalidBallots } from '../testnet/init'
import { verify } from './zkp-fiat-shamir'

type Tally = {
    k: BN,
    address: string,
    ballots: Ballot[]
}

type Res = {
    V: number,
    X: ECP,
    Y: ECP,
    proof: Proof,
    invalidBallots: string[]
    nBallot: number
}

export function tally(t: Tally): Res {
    if (!isValidPower(t.k)) {
        throw new Error('Invalid private key')
    }

    if (!isAddress(t.address)) {
        throw new Error('Invalid account address')
    }

    // Verify ballots & aggregate h and y
    let invalidBallots: string[] = []
    let H: ECP, Y: ECP
    t.ballots.filter(ballot => {
        if (!verifyBallot(ballot)) {
            invalidBallots.push(ballot.proof.address)
            return false
        }

        if (typeof H === 'undefined') {
            H = ballot.h
            Y = ballot.y
        } else {
            H = H.add(ballot.h)
            Y = Y.add(ballot.y)
        }

        return true
    })

    // X = H^k
    const X = H.mul(t.k)

    // Generate Proof of k
    const proof: Proof = prove({
        address: t.address,
        h: H,
        y: X,
        x: t.k
    })

    // Compute the number of yes votes, V
    let V = 0
    const nValidBallot = t.ballots.length - invalidBallots.length
    if (!X.eq(Y)) { // only run the loop if there is at least one yes vote
        // g^v = Y/X
        const gV = Y.add(ecInv(X))

        for (V = 1; V <= nValidBallot; V++) {
            if (gV.eq(g.mul(new BN(V)))) {
                break
            }
        }
    }

    return {
        V: V,
        X: X,
        Y: Y,
        proof: proof,
        invalidBallots: invalidBallots,
        nBallot: t.ballots.length
    }
}

export function verifyTallyRes(r: Res): boolean {
    // Check range of V
    if (r.V < 0 || r.V > r.nBallot-invalidBallots.length) {
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