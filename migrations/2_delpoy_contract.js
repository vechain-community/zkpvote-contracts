const BinaryVote = artifacts.require("BinaryVoteV2");
const VotingContract = artifacts.require("VotingContractV2");

module.exports = function (deployer) {
    deployer.deploy(BinaryVote)
        .then(() => BinaryVote.deployed())
        .then(() => deployer.deploy(VotingContract, BinaryVote.address));
};