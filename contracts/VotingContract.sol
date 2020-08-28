pragma solidity >=0.5.3 <0.7.0;

contract BinaryVoteInterface {
    function setAuthPubKey(uint256[2] calldata gk) external;

    function cast(
        uint256[2] calldata h,
        uint256[2] calldata y,
        uint256[4] calldata params,
        uint256[2] calldata a1,
        uint256[2] calldata b1,
        uint256[2] calldata a2,
        uint256[2] calldata b2
    ) external;

    function beginTally() external;

    function endTally() external;

    function setTallyRes(
        address[] calldata nullVoters,
        uint256 V,
        uint256[2] calldata X,
        uint256[2] calldata Y,
        uint256[2] calldata H,
        uint256[2] calldata t,
        uint256 r
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
            uint256[2] memory,
            uint256[2] memory,
            uint256[4] memory,
            uint256[2] memory,
            uint256[2] memory,
            uint256[2] memory,
            uint256[2] memory
        );
}

contract VotingContract {
    mapping(address => bytes32[]) public voteID;
    mapping(bytes32 => address) public voteAddr;
    mapping(bytes32 => address) public voteAuth;

    address public creator;

    constructor(address _creator) public {
        creator = _creator;
    }

    modifier onlyCreator() {
        require(uint256(creator) > 0 && msg.sender == creator, "Require creator");
        _;
    }

    function newBinaryVote(address auth, address voteContract) onlyCreator() external {
        bytes32 id = keccak256(abi.encode(auth, voteContract));

        voteID[msg.sender].push(id);
        voteAddr[id] = address(voteContract);
        voteAuth[id] = auth;

        emit NewBinaryVote(id, auth, voteContract);
    }

    function setAuthPubKey(bytes32 id, uint256[2] calldata _gk) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.setAuthPubKey(_gk);
    }

    function cast(
        bytes32 id,
        uint256[2] calldata h,
        uint256[2] calldata y,
        uint256[4] calldata params,
        uint256[2] calldata a1,
        uint256[2] calldata b1,
        uint256[2] calldata a2,
        uint256[2] calldata b2
    ) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.cast(h, y, params, a1, b1, a2, b2);

        emit CastBinaryBallot(id, msg.sender, keccak256(abi.encode(h, y)));
    }

    function beginTally(bytes32 id) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.beginTally();

        emit BeginTally(id, msg.sender);
    }

    function endTally(bytes32 id) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.endTally();

        emit EndTally(id, msg.sender);
    }

    function setTallyRes(
        bytes32 id,
        address[] calldata nullVoters,
        uint256 V,
        uint256[2] calldata X,
        uint256[2] calldata Y,
        uint256[2] calldata H,
        uint256[2] calldata t,
        uint256 r
    ) external {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        c.setTallyRes(nullVoters, V, X, Y, H, t, r);

        emit SetTallyRes(id, msg.sender, V, keccak256(abi.encode(X, Y)));
    }

    function verifyBallot(bytes32 id, address a) external view returns (bool) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.verifyBallot(a);
    }
    
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

    function getNumVote(address a) external view returns (uint256) {
        return voteID[a].length;
    }

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

    function getNumNullVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNumNullVoter();
    }

    function getNullVoter(bytes32 id, uint256 i) external view returns (address) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNullVoter(i);
    }

    function getNumVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getNumVoter();
    }

    function getVoter(bytes32 id, uint256 i) external view returns (address) {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getVoter(i);
    }

    function getBallot(bytes32 id, address a)
        external
        view
        returns (
            uint256[2] memory,
            uint256[2] memory,
            uint256[4] memory,
            uint256[2] memory,
            uint256[2] memory,
            uint256[2] memory,
            uint256[2] memory
        )
    {
        require(uint256(voteAddr[id]) > 0, "Vote ID does not exist");
        BinaryVoteInterface c = BinaryVoteInterface(voteAddr[id]);

        return c.getBallot(a);
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
