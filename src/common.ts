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
export const p: BN = p256.p
export const a: BN = p256.a
export const b: BN = p256.b