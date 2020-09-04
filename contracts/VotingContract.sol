pragma solidity >=0.5.3 <0.7.0;

contract BinaryVoteInterface {
    function setAuthPubKey(uint256 gk, uint8 gkPrefix) external;

    function cast(
        uint256 h,
        uint256 y,
        uint256[8] calldata zkp,
        uint256 prefix
    ) external;

    function beginTally() external;

    function endTally() external;

    function setTallyRes(
        address[] calldata nullVoters,
        uint256 V,
        uint256 X,
        uint256 Y,
        uint256[3] calldata zkp,
        uint256 prefix
    ) external;

    function verifyBallot(address a) external view returns (bool);

    function verifyTallyRes() external view returns (bool);

    function getAuthPubKey() external view returns (uint256[2] memory);

    function getNumVoter() external view returns (uint256);

    function getVoter(uint256 i) external view returns (address);

    function getNumNullVoter() external view returns (uint256);

    function getNullVoter(uint256 i) external view returns (address);

    function getBallot(address a)
        external
        view
        returns (
            uint256,
            uint256,
            uint256[8] memory,
            uint256
        );
}

/// @title Voting Contract
/// @author Peter Zhou
/// @dev Main contract used to conduct a privacy-preserved voting
contract VotingContract {
    mapping(address => bytes32[]) public voteID;
    mapping(bytes32 => address) public voteAddr;
    mapping(bytes32 => address) public voteAuth;

    address public creator;

    /// @dev constructor
    /// @param _creator address of the deployed contract VoteCreator
    constructor(address _creator) public {
        creator = _creator;
    }

    modifier onlyCreator() {
        require(uint256(creator) > 0 && msg.sender == creator, "Require creator");
        _;
    }

    /// @dev Register a new vote created by the creator contract
    /// @param auth address of the account used by the authority
    /// @param voteContract address of the instance of contract BinaryVote
    function newBinaryVote(address auth, address voteContract) onlyCreator() external {
        bytes32 id = keccak256(abi.encode(auth, voteContract));

        voteID[msg.sender].push(id);
        voteAddr[id] = address(voteContract);
        voteAuth[id] = auth;

        emit NewBinaryVote(id, auth, voteContract);
    }

    /// @dev Set public key by the authority
    /// @param id Vote ID
    /// @param _gk Public key
    function setAuthPubKey(bytes32 id, uint256 _gk, uint8 _gkPrefix) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.setAuthPubKey(_gk, _gkPrefix);
    }

    /// @dev Cast a yes/no ballot
    /// @param id Vote ID
    /// @param h g^a
    /// @param y (g^ka)(g^v) v\in{0,1}
    /// @param zkp proof of a binary voting value; zkp = [d1, r1, d2, r2, a1, b1, a2, b2]
    /// @param prefix parity bytes (0x02 even, 0x03 odd) for for compressed ec points h | y | a1 | b1 | a2 | b2
    function cast(
        bytes32 id,
        uint256 h,
        uint256 y,
        uint256[8] calldata zkp,
        uint256 prefix
    ) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.cast(h, y, zkp, prefix);

        emit CastBinaryBallot(
            id, 
            msg.sender, 
            keccak256(abi.encode(
                h, getByteVal(prefix, 5),
                y, getByteVal(prefix, 4)
            ))
        );
    }

    /// @dev Start tally by the authority
    /// @param id Vote ID
    function beginTally(bytes32 id) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.beginTally();

        emit BeginTally(id, msg.sender);
    }

    /// @dev Start tally by the authority
    /// @param id Vote ID
    function endTally(bytes32 id) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.endTally();

        emit EndTally(id, msg.sender);
    }

    /// @dev Upload the tally result
    /// @param id Vote ID
    /// @param nullVoters addresses of the voters whose ballots are invalid
    /// @param V Total number of yes votes
    /// @param X prod_i(h_i) 
    /// @param Y prod_i(y_i)
    /// @param zkp proof of the knowedge of k; zkp = [H, t, r]
    /// @param prefix parity bytes (0x02 even, 0x03 odd) for compressed ec points X | Y | H | t
    function setTallyRes(
        bytes32 id,
        address[] calldata nullVoters,
        uint256 V,
        uint256 X,
        uint256 Y,
        uint256[3] calldata zkp,
        uint256 prefix
    ) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.setTallyRes(nullVoters, V, X, Y, zkp, prefix);

        emit SetTallyRes(
            id, msg.sender, V, 
            keccak256(abi.encode(
                X, getByteVal(prefix, 3),
                Y, getByteVal(prefix, 2)
            ))
        );
    }

    /// @dev Verify a cast ballot
    /// @param id Vote ID
    /// @param a address of the account used to cast the ballot
    /// @return true or false
    function verifyBallot(bytes32 id, address a) external view returns (bool) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.verifyBallot(a);
    }
    
    /// @dev Verify the tally result
    /// @notice After the tally is ended by the authority
    /// @param id Vote ID
    /// @return true or false
    function verifyTallyRes(bytes32 id) external view returns (bool) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        uint256 n = c.getNumNullVoter();
        address a;
        for(uint256 i = 0; i < n; i++) {
            a = c.getNullVoter(i);
            if(c.verifyBallot(a)) {
                return false;
            }
        }

        return c.verifyTallyRes();
    }

    /// @dev Get the number of votes initiated by a parcular account
    /// @param a Account address
    /// @return Number of votes
    function getNumVote(address a) external view returns (uint256) {
        return voteID[a].length;
    }

    /// @dev Get authority public key
    /// @param id Vote ID
    /// @return public key
    function getAuthPubKey(bytes32 id)
        external
        view
        returns (uint256[2] memory)
    {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);
        uint256[2] memory gk = c.getAuthPubKey();

        return gk;
    }

    /// @dev Get the number of accounts used to cast ballots are invalidated by the authority
    /// @param id Vote ID
    /// @return Number of accounts
    function getNumNullVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNumNullVoter();
    }

    /// @dev Get the address of a particular account used to cast an invalid ballot
    /// @param id Vote ID
    /// @param i Index
    /// @return Account address
    function getNullVoter(bytes32 id, uint256 i) external view returns (address) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNullVoter(i);
    }

    /// @dev Get the number of accounts used to cast ballots are invalidated by the authority
    /// @param id Vote ID
    /// @return Number of accounts
    function getNumVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNumVoter();
    }

    /// @dev Get the address of a particular account used to cast a ballot
    /// @param id Vote ID
    /// @param i Index
    /// @return Account address
    function getVoter(bytes32 id, uint256 i) external view returns (address) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getVoter(i);
    }

    /// @dev Get a ballot stored in the contract indexed by the account address
    /// @param id Vote ID
    /// @param a account address
    /// @return h
    /// @return y
    /// @return zkp
    /// @return prefix
    function getBallot(bytes32 id, address a)
        external
        view
        returns (
            uint256,
            uint256,
            uint256[8] memory,
            uint256
        )
    {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getBallot(a);
    }

    function getByteVal(uint256 b, uint256 i) internal pure returns (uint8) {
        return uint8((b >> i * 8) & 0xff);
    }

    event NewBinaryVote(bytes32 indexed id, address indexed from, address addr);
    event CastBinaryBallot(
        bytes32 indexed id,
        address indexed from,
        bytes32 ballotHash
    );
    event BeginTally(bytes32 indexed id, address indexed from);
    event EndTally(bytes32 indexed id, address indexed from);
    event SetTallyRes(
        bytes32 indexed id,
        address indexed from,
        uint256 V,
        bytes32 tallyHash
    );
}
