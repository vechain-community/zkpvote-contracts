const BN = require('bn.js');

var deriveY = function (x, prefix, a, b, p) {
    let y = expMod(x, new BN(3), p);
    y = y.add(x.mul(a).mod(p)).mod(p);
    y = y.add(b).mod(p);

    y = expMod(y, p.add(new BN(1)).div(new BN(4)), p);

    return y.add(new BN(prefix)).mod(new BN(2)).isZero() ? y : p.sub(y);
}

var expMod = function (a, b, n) {
    a = a.mod(n);
    let result = new BN(1);
    let x = a.clone();

    while (!b.isZero()) {
        const leastSignificantBit = b.mod(new BN(2));
        b = b.div(new BN(2));

        if (!leastSignificantBit.isZero()) {
            result = result.mul(x).mod(n);
        }

        x = x.mul(x).mod(n);
    }
    return result;
};

(() => {
    const a = new BN('ffffffff00000001000000000000000000000000fffffffffffffffffffffffc', 16);
    const b = new BN('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', 16);
    const p = new BN('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', 16);
    const x = new BN('16e86dd33ff630aa620b2284cecdd301c98c60e552b31af18c1e890a546960ed', 16);
    const y = new BN('79e436641e3ca9721465ccfa9dd8b9ea5069fd1e020337a96f9d09fd50e6b56f', 16);

    const buff = new BN('0203', 16).toBuffer(BN.BigEndian);
    console.log(buff);

    const _y = deriveY(x, new BN(buff[1]), a, b, p);

    console.log(_y.toString(16));
})();