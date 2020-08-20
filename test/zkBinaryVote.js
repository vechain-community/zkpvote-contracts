const ZkBinaryVote = artifacts.require("ZkBinaryVote");

const fs = require("fs");
// const { assert } = require("console");
var fpath = __dirname + "/data/"

contract("ZkBinaryVote", async accounts => {
    it("Authority sets its public key", async () => {
        let vote = await ZkBinaryVote.deployed();
        
        let obj = require(fpath + "auth_public_key.json");
        await vote.setAuthPubKey(web3.utils.toBN(obj["gkx"]), web3.utils.toBN(obj["gky"]), { from: accounts[0] });

        let gk = await vote.gk.call();

        assert.equal(web3.utils.toHex(gk["0"]), obj["gkx"], "gkX doesn't match");
        assert.equal(web3.utils.toHex(gk["1"]), obj["gky"], "gkY doesn't match");
    });

    it("cast valid & invalid ballots", async () => {
        let vote = await ZkBinaryVote.deployed();
        
        let obj = require(fpath + "vote_0.json");
        obj = obj["proof"]
        let params = [
            web3.utils.toBN(obj["d1"]),
            web3.utils.toBN(obj["r1"]),
            web3.utils.toBN(obj["d2"]),
            web3.utils.toBN(obj["r2"]),
        ];
        let ga = [web3.utils.toBN(obj["gax"]), web3.utils.toBN(obj["gay"])];
        let y = [web3.utils.toBN(obj["yx"]), web3.utils.toBN(obj["yy"])];
        let a1 = [web3.utils.toBN(obj["a1x"]), web3.utils.toBN(obj["a1y"])];
        let b1 = [web3.utils.toBN(obj["b1x"]), web3.utils.toBN(obj["b1y"])];
        let a2 = [web3.utils.toBN(obj["a2x"]), web3.utils.toBN(obj["a2y"])];
        let b2 = [web3.utils.toBN(obj["b2x"]), web3.utils.toBN(obj["b2y"])];

        // let res = await vote.verifyBinaryZKP.call(ga, y, params, a1, b1, a2, b2, {from: accounts[1]});
        // assert.equal(res, true);

        let tx = await vote.cast(ga, y, params, a1, b1, a2, b2, {from: accounts[1]});
        // console.log(tx)
        assert.equal(tx.logs[0].args["from"], accounts[1]);
        assert.equal(
            tx.logs[0].args["ballotHash"], 
            web3.utils.sha3(web3.eth.abi.encodeParameters(
                ['uint256','uint256','uint256','uint256'],
                [obj["gax"], obj["gay"],obj["yx"], obj["yy"]])),
            "event doesn't match"
        );
    });

    it("test ballot verification", async () => {
        let vote = await ZkBinaryVote.deployed();
        let res = await vote.verifyBallot.call(accounts[1]);
        assert.equal(res, true, "should return true");
    });

    it("test submitting tally results", async () => {
        let vote = await ZkBinaryVote.deployed();
        
        let obj = require(fpath + "tally.json");

        let V = obj["v"];
        let X = [obj["xx"],obj["xy"]];
        let Y = [obj["yx"],obj["yy"]];

        pf = obj["proof"]; 
        let H = [pf["hx"], pf["hy"]];
        let t = [pf["tx"], pf["ty"]];
        let r = pf["r"];

        await vote.invalidateBallots([]);
        let state = await vote.state.call();
        // console.log(state);
        assert.equal(state, 2, "should be State.Tally");

        let tx = await vote.tally(V, X, Y, H, t, r);
        assert.equal(tx.logs[0].args['V'], V, "V");
        assert.equal(
            tx.logs[0].args['tallyHash'], 
            web3.utils.sha3(web3.eth.abi.encodeParameters(['uint256[2]', 'uint256[2]'], [X, Y])),
            "tallyHash"
        );

        let res = await vote.verifyTallyRes()
    });
});