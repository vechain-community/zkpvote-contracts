import { randomBytes } from 'crypto'
import BN from 'bn.js'

import { n } from './ec'

export function isValidPower(x: BN): boolean {
    return x.gt(new BN(0)) && x.lt(n)
}

export function randPower(): BN {
    for (; ;) {
        const x = new BN(randomBytes(32))
        if (isValidPower(x)) {
            return x
        }
    }
}

export function pre(s: string): string {
    const v = parseInt(s.charAt(s.length - 1), 16)
    return v % 2 == 0 ? '02' : '03'
}

export function randAddress(): string {
    return '0x' + new BN(randomBytes(20)).toString('hex', 20)
}

export function toHex(x: number | string | BN, enc = 16, len = 32): string {
    if (len <= 0 || len % 2 != 0) {
        throw new Error('Invalid hex string length')
    }

    return '0x' + new BN(x, enc).toString('hex', len)
}