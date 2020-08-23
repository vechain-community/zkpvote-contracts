pragma solidity >=0.5.3 <0.7.0;

import "./BinaryVote.sol";

contract VotingContractInterface {
    function newBinaryVote(address auth, address voteContract) external;
}

contract VoteCreator {
    address public owner;
    address public c;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(uint256(owner) > 0 && msg.sender == owner, "Require contract owner");
        _;
    }

    function setVotingContract(address _c) external onlyOwner() {
        c = _c;
        owner = address(0);
    }

    function newBinaryVote() external {
        require(uint256(c) > 0, "Voting contract has not been set");

        BinaryVote vote = new BinaryVote();

        VotingContractInterface(c).newBinaryVote(msg.sender, address(vote));

        emit NewBinaryVote(msg.sender, address(vote));
    }

    event NewBinaryVote(address indexed from, address indexed voteContract);
}