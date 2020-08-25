const VotingContract = artifacts.require("VotingContract");
const VoteCreator = artifacts.require("VoteCreator");
const fs = require("fs");

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
        await vc.setAuthPubKey(id, [obj.gkx, obj.gky], { from: accounts[0] });

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

            const ga = [b.hx, b.hy];
            const y = [b.yx, b.yy];
            const params = [p.d1, p.r1, p.d2, p.r2];
            const a1 = [p.a1x, p.a1y];
            const b1 = [p.b1x, p.b1y];
            const a2 = [p.a2x, p.a2y];
            const b2 = [p.b2x, p.b2y];

            tx = await vc.cast(id, ga, y, params, a1, b1, a2, b2, { from: accounts[i + 1] });
            
            // check event
            assert.equal(
                tx.logs[0].args.ballotHash,
                web3.utils.sha3(web3.eth.abi.encodeParameters(
                    ['uint256[2]', 'uint256[2]'],
                    [ga, y])),
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

            obj = utils.raw2norm(raw);
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
        tx = await vc.setTallyRes(
            id,
            invalid_addr,
            res.v,
            [res.xx, res.xy],
            [res.yx, res.yy],
            [res.proof.hx, res.proof.hy],
            [res.proof.tx, res.proof.ty],
            res.proof.r,
            { from: accounts[0] }
        );
        // check event
        assert.equal(tx.logs[0].args.V, res.v);
        assert.equal(
            tx.logs[0].args.tallyHash,
            web3.utils.sha3(web3.eth.abi.encodeParameters(
                ['uint256', 'uint256', 'uint256', 'uint256'],
                [res.xx, res.xy, res.yx, res.yy])),
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

var utils = {
    raw2norm: function (raw) {
        const p = {
            // gax: web3.utils.toHex(raw["0"][0]),
            // gay: web3.utils.toHex(raw["0"][1]),
            // yx: web3.utils.toHex(raw["1"][0]),
            // yy: web3.utils.toHex(raw["1"][1]),
            d1: web3.utils.toHex(raw["2"][0]),
            r1: web3.utils.toHex(raw["2"][1]),
            d2: web3.utils.toHex(raw["2"][2]),
            r2: web3.utils.toHex(raw["2"][3]),
            a1x: web3.utils.toHex(raw["3"][0]),
            a1y: web3.utils.toHex(raw["3"][1]),
            b1x: web3.utils.toHex(raw["4"][0]),
            b1y: web3.utils.toHex(raw["4"][1]),
            a2x: web3.utils.toHex(raw["5"][0]),
            a2y: web3.utils.toHex(raw["5"][1]),
            b2x: web3.utils.toHex(raw["6"][0]),
            b2y: web3.utils.toHex(raw["6"][1])
        };
        return {
            hx: web3.utils.toHex(raw["0"][0]),
            hy: web3.utils.toHex(raw["0"][1]),
            yx: web3.utils.toHex(raw["1"][0]),
            yy: web3.utils.toHex(raw["1"][1]),
            proof: p
        };
    }
};