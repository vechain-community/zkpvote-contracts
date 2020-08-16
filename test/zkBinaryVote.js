const ZkBinaryVote = artifacts.require("ZkBinaryVote");

const fs = require("fs");

contract("ZkBinaryVote", async accounts => {
    it("test setAuthPubKey", async () => {
        let vote = await ZkBinaryVote.deployed();
        
        let obj = require(__dirname + "/data/auth_public_key.json");
        await vote.setAuthPubKey(web3.utils.toBN(obj["gkx"]), web3.utils.toBN(obj["gky"]), { from: accounts[0] });

        let gkX = await vote.gkX.call();
        let gkY = await vote.gkY.call();

        assert.equal(web3.utils.toHex(gkX), obj["gkx"]);
        assert.equal(web3.utils.toHex(gkY), obj["gky"]);
    });

    it("test ballot verfication", async () => {
        let vote = await ZkBinaryVote.deployed();
        
        let obj = require(__dirname + "/data/vote_0.json");
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

        let res = await vote.verifyBinaryZKProof(params, ga, y, a1, b1, a2, b2);
        assert.equal(res, true);
    });
});