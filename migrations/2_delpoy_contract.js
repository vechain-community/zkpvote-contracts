const EllipticCurve = artifacts.require("EllipticCurve");
const ZkBinaryVote = artifacts.require("ZkBinaryVote");

module.exports = function (deployer) {
    deployer.deploy(EllipticCurve);
    deployer.link(EllipticCurve, ZkBinaryVote);
    deployer.deploy(ZkBinaryVote);
};
