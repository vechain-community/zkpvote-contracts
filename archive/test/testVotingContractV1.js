const VotingContract = artifacts.require("VotingContract");
const VoteCreator = artifacts.require("VoteCreator");
const fs = require("fs");
const BN = require('bn.js');

contract("VotingContract", async (accounts) => {
    it("test run", async () => {
        let vc = await VotingContract.deployed();
        let cr = await VoteCreator.deployed();
        await cr.setVotingContract(vc.address);

        const fpath = __dirname + "/data/"

        //////////////////////////////
        // New binary vote
        //////////////////////////////
        let tx = await cr.newBinaryVote(); 

        const auth = tx.logs[0].args.from;
        const addr = tx.logs[0].args.voteContract;
        const id = web3.utils.sha3(web3.eth.abi.encodeParameters(
            ["address", "address"], [auth, addr]
        ));

        const val = await vc.voteAddr(id);
        assert.equal(val, addr);

        //////////////////////////////
        // Set authority public key
        //////////////////////////////
        let obj = require(fpath + "auth-pub-key.json");
        let prefix = utils.isEven(obj.gky) ? 2 : 3;

        await vc.setAuthPubKey(id, obj.gkx, prefix, { from: accounts[0] });

        const gk = await vc.getAuthPubKey(id);

        assert.equal(web3.utils.toHex(gk[0]), obj.gkx);
        assert.equal(web3.utils.toHex(gk[1]), obj.gky);

        // ////////////////////////////////////////////////////////////////////////////
        // // Ballot casting
        // // 9 ballots in total and the last 3 are invalidated by set a1x <- a1x + 1
        // ////////////////////////////////////////////////////////////////////////////
        const origin = require(fpath + "bin-ballot.json");

        for (i = 0; i < origin.length; i++) {
            const b = origin[i];
            const p = b.proof;

            const zkp = [p.d1, p.r1, p.d2, p.r2, p.a1x, p.b1x, p.a2x, p.b2x];
            prefix = '0x';
            prefix += utils.isEven(b.hy) ? '02' : '03';
            prefix += utils.isEven(b.yy) ? '02' : '03';
            prefix += utils.isEven(p.a1y) ? '02' : '03';
            prefix += utils.isEven(p.b1y) ? '02' : '03';
            prefix += utils.isEven(p.a2y) ? '02' : '03';
            prefix += utils.isEven(p.b2y) ? '02' : '03';

            tx = await vc.cast(id, b.hx, b.yx, zkp, prefix, { from: accounts[i + 1] });

            // check event
            let pfx1 = utils.isEven(b.hy) ? '02' : '03';
            let pfx2 = utils.isEven(b.yy) ? '02' : '03';
            assert.equal(
                tx.logs[0].args.ballotHash,
                web3.utils.sha3(web3.eth.abi.encodeParameters(
                    ['uint256', 'uint8', 'uint256', 'uint8'],
                    [b.hx, pfx1, b.yx, pfx2])),
                "Error in casting ballot (" + i + ")"
            );
        }

        /////////////////////////////////////////////////////////
        // download ballots for off-chain verification/tallying
        /////////////////////////////////////////////////////////
        const dl = [];
        const n = await vc.getNumVoter(id);

        for (i = 0; i < n; i++) {
            const addr = await vc.getVoter(id, i);
            const raw = await vc.getBallot(id, addr);

            obj = utils.rawToNormBallot(raw);
            obj.proof.data = addr;
            obj.proof.gxk = web3.utils.toHex(gk[0]);
            obj.proof.gky = web3.utils.toHex(gk[1]);
            dl.push(obj)
        }

        fs.writeFileSync(fpath + "dl-bin-ballot.json", JSON.stringify(dl));

        /////////////////////////////////////
        // Authority uploads tally result
        /////////////////////////////////////
        await vc.beginTally(id, { from: accounts[0] });

        const invalid_addr = require(fpath + "invalid-bin-addr.json");
        let res = require(fpath + "bin-tally-res.json");

        prefix = '0x';
        prefix += utils.isEven(res.xy) ? '02' : '03';
        prefix += utils.isEven(res.yy) ? '02' : '03';
        prefix += utils.isEven(res.proof.hy) ? '02' : '03';
        prefix += utils.isEven(res.proof.ty) ? '02' : '03';

        tx = await vc.setTallyRes(
            id,
            invalid_addr,
            res.v,
            res.xx,
            res.yx,
            [res.proof.hx, res.proof.tx, res.proof.r],
            prefix,
            { from: accounts[0] }
        );
        // check event
        pfx1 = utils.isEven(res.xy) ? '02' : '03';
        pfx2 = utils.isEven(res.yy) ? '02' : '03';
        assert.equal(tx.logs[0].args.V, res.v);
        assert.equal(
            tx.logs[0].args.tallyHash,
            web3.utils.sha3(web3.eth.abi.encodeParameters(
                ['uint256', 'uint8', 'uint256', 'uint8'],
                [res.xx, pfx1, res.yx, pfx2])),
            "Error in setting tally result"
        );

        /////////////////////////////
        // Verify tally result
        /////////////////////////////
        await vc.endTally(id, { from: accounts[0] });

        res = await vc.verifyTallyRes(id);
        assert.equal(res, true, "Invalid tally result")
    });
});

var utils = (function () {
    const _a = new BN('ffffffff00000001000000000000000000000000fffffffffffffffffffffffc', 16);
    const _b = new BN('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', 16);
    const _p = new BN('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', 16);

    function rawToNormBallot(raw) {
        const prefix = raw["3"].toBuffer(BN.BigEndian);
        const proof = {
            d1: '0x' + raw["2"][0].toString(16, 64),
            r1: '0x' + raw["2"][1].toString(16, 64),
            d2: '0x' + raw["2"][2].toString(16, 64),
            r2: '0x' + raw["2"][3].toString(16, 64),
            a1x: '0x' + raw["2"][4].toString(16, 64),
            a1y: '0x' + _deriveY(raw["2"][4], new BN(prefix[2])).toString(16, 64),
            b1x: '0x' + raw["2"][5].toString(16, 64),
            b1y: '0x' + _deriveY(raw["2"][5], new BN(prefix[3])).toString(16, 64),
            a2x: '0x' + raw["2"][6].toString(16, 64),
            a2y: '0x' + _deriveY(raw["2"][6], new BN(prefix[4])).toString(16, 64),
            b2x: '0x' + raw["2"][7].toString(16, 64),
            b2y: '0x' + _deriveY(raw["2"][7], new BN(prefix[5])).toString(16, 64)
        };
        return {
            hx: '0x' + raw["0"].toString(16, 64),
            hy: '0x' + _deriveY(raw["0"], new BN(prefix[0])).toString(16, 64),
            yx: '0x' + raw["1"].toString(16, 64),
            yy: '0x' + _deriveY(raw["1"], new BN(prefix[1])).toString(16, 64),
            proof: proof
        };
    }

    function isEven(s) {
        const v = parseInt(s.charAt(s.length - 1), 16);
        return v % 2 == 0;
    }

    function _deriveY(x, prefix) {
        let y = _expMod(x, new BN(3), _p);
        y = y.add(x.mul(_a).mod(_p)).mod(_p);
        y = y.add(_b).mod(_p);

        y = _expMod(y, _p.add(new BN(1)).div(new BN(4)), _p);

        return y.add(new BN(prefix)).mod(new BN(2)).isZero() ? y : _p.sub(y);
    }

    function _expMod(a, b, n) {
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
    }

    return {
        rawToNormBallot: rawToNormBallot,
        isEven: isEven
    }
})();