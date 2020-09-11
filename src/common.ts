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
export const g: ECP = p256.curve.g
export const n: BN = p256.curve.n
export const p: BN = p256.curve.p
export const a: BN = p256.curve.a
export const b: BN = p256.curve.b

export function point(x: BN | string, y: BN | string): ECP {
    return p256.curve.point(x, y, false)
}