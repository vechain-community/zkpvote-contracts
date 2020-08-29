pragma solidity >=0.5.3 <0.7.0;

import "./BinaryVote.sol";

contract VotingContractInterface {
    function newBinaryVote(address auth, address voteContract) external;
}

/// @author Peter Zhou
/// @title Contract for creating instances of contract BinaryVote
contract VoteCreator {
    address public owner;
    address public c;
    address public lib;

    /// Constructor
    // constructor(address _lib) public {
    //     require(uint256(_lib) > 0, "Invalid EC library address");

    //     owner = msg.sender;
    //     lib = _lib;
    // }
    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(uint256(owner) > 0 && msg.sender == owner, "Require contract owner");
        _;
    }

    /// Connect to the deployed voting contract and give up the ownership
    /// @param _c address of the deployed voting contract
    function setVotingContract(address _c) external onlyOwner() {
        c = _c;
        owner = address(0);
    }

    /// Create an instance of contract BinaryVote and register it in the deployed voting contract
    function newBinaryVote() external {
        // require(uint256(lib) > 0, "EC library contract has not been set");
        require(uint256(c) > 0, "Voting contract has not been set");

        BinaryVote vote = new BinaryVote();
        // BinaryVote vote = new BinaryVote(lib);

        VotingContractInterface(c).newBinaryVote(msg.sender, address(vote));

        emit NewBinaryVote(msg.sender, address(vote));
    }

    event NewBinaryVote(address indexed from, address indexed voteContract);
}