const EllipticCurve = artifacts.require("EllipticCurve")
// const BinaryVote = artifacts.require("BinaryVote");
const VoteCreator = artifacts.require("VoteCreator.sol");
const VotingContract = artifacts.require("VotingContract");

module.exports = function (deployer) {
    // deployer.deploy(EllipticCurve)
    // .then(() => EllipticCurve.deployed())
    // .then(() => deployer.deploy(VoteCreator, EllipticCurve.address))
    deployer.deploy(VoteCreator)
    .then(() => VoteCreator.deployed())
    .then(() => deployer.deploy(VotingContract, VoteCreator.address))
    .then(() => VotingContract.deployed());
};