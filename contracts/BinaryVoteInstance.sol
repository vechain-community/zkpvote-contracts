pragma solidity >=0.5.3 <0.7.0;

/// @title Instance of Binary Vote Contract
/// @author Peter Zhou
/// @dev Implementation of a privacy-preserved voting protocol
/// @notice Curve p256 is implemented
/// @notice Support YES/NO ballots only
contract BinaryVoteInstance {
    // content of a ballot
    struct Ballot {
        uint256 h; // public key
        uint256 y; // encrypted vote
        uint256[8] zkp; // [d1, r1, d2, r2, a1, b1, a2, b2];
        uint256 prefix; // order: h | y | a1 | b1 | a2 | b2
    }

    struct TallyRes {
        uint256 V; // number of yes votes
        // Values from which V is computed and to be verified
        uint256 X; // X = H^k
        uint256 Y; // Y = X * g^V
        uint256[3] zkp; // [H, t, r]
        uint256 prefix; // order: X | Y | H | t
    }

    // Authority
    address private auth; // account address
    uint8 private gkPrefix;
    uint256 private gk; // authority-generated public key

    // Ballots
    address[] private voters; // addresses of the accounts that have cast a ballot
    mapping(address => bool) private checkBallot; // mapping used to check whether an account has cast a ballot
    mapping(address => Ballot) private ballots;

    // Data uploaded by authority
    address[] private nullVoters; // addresses of the accounts that have cast an invalid ballot
    mapping(address => bool) private checkInvalidBallot; // mapping used to check whether an account has cast an invalid ballot
    TallyRes private tallyRes; // outputs of the tally carried by authority off-chain
    bool private hasSetTallyRes;

    enum State {
        Init,
        Cast, // start after authority sets the public key
        Tally, // start after authority calls function beginTally()
        End // ends after authority calls function endTally()
    }
    State state;

    // Deployed BinaryVote contract
    address lib;

    modifier onlyAuth() {
        // Modifier
        require(tx.origin == auth, "Only authority can call this.");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state");
        _;
    }

    constructor(address _lib) public {
        lib = _lib;

        auth = tx.origin;
        state = State.Init;
        hasSetTallyRes = false;
    }

    /// @dev Set compressed public key by the authority
    /// @param _gk x coordinate
    /// @param _gkPrefix prefix
    function setAuthPubKey(uint256 _gk, uint8 _gkPrefix)
        external
        onlyAuth
        inState(State.Init)
    {
        (bool success, bytes memory _result) = lib.delegatecall(
            abi.encodeWithSignature(
                "setAuthPubKey(uint256,uint8)",
                _gk,
                _gkPrefix
            )
        );

        require(success, "setAuthPubKey failed");
    }

    /// @dev Cast a yes/no ballot8
    /// @param h g^a
    /// @param y (g^ka)(g^v) v\in{0,1}
    /// @param zkp proof of a binary voting value; zkp = [d1, r1, d2, r2, a1, b1, a2, b2]
    /// @param prefix parity bytes (0x02 even, 0x03 odd) for for compressed ec points h | y | a1 | b1 | a2 | b2
    function cast(
        uint256 h,
        uint256 y,
        uint256[8] calldata zkp,
        uint256 prefix
    ) external inState(State.Cast) {
        (bool success, bytes memory _result) = lib.delegatecall(
            abi.encodeWithSignature(
                "cast(uint256,uint256,uint256[8],uint256)",
                h,
                y,
                zkp,
                prefix
            )
        );

        require(success, "cast failed");
    }

    /// @dev Start tally by the authority
    function beginTally() external onlyAuth() inState(State.Cast) {
        state = State.Tally;
    }

    /// @dev End tally by the authority
    function endTally() external onlyAuth() inState(State.Tally) {
        require(hasSetTallyRes, "Tally result not yet set");
        state = State.End;
    }

    /// @dev Upload the tally result
    /// @param nulls addresses of the voters whose ballots are invalid
    /// @param V Total number of yes votes
    /// @param X H^k
    /// @param Y prod_i(y_i)
    /// @param zkp proof of the knowedge of k; zkp = [H, t, r]
    /// @param prefix parity bytes (0x02 even, 0x03 odd) for compressed ec points X | Y | H | t
    function setTallyRes(
        address[] calldata nulls,
        uint256 V,
        uint256 X,
        uint256 Y,
        uint256[3] calldata zkp,
        uint256 prefix
    ) external onlyAuth() inState(State.Tally) {
        for (uint256 i = 0; i < nulls.length; i++) {
            address a = nulls[i];

            if (checkBallot[a] && !checkInvalidBallot[a]) {
                checkInvalidBallot[a] = true;
                nullVoters.push(a);
            }
        }

        tallyRes = TallyRes({V: V, X: X, Y: Y, zkp: zkp, prefix: prefix});
        hasSetTallyRes = true;
    }

    /// @dev Verify a cast ballot
    /// @param a address of the account used to cast the ballot
    /// @return true or false
    function verifyBallot(address a) external returns (bool) {
        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("verifyBallot(address)", a)
        );

        require(success, "verifyBallot failed");

        return abi.decode(result, (bool));
    }

    /// @dev Verify the tally result after the tally is ended by the authority
    /// @return true or false
    function verifyTallyRes() external inState(State.End) returns (bool) {
        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("verifyTallyRes()")
        );

        require(success, "verifyTallyRes failed");

        return abi.decode(result, (bool));
    }

    /// @dev Get authority public key
    /// @return Public key
    function getAuthPubKey() external returns (uint256[2] memory) {
        // return getECPoint(gk, gkPrefix);
        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("getAuthPubKey()")
        );

        require(success, "getAuthPubKey failed");

        return abi.decode(result, (uint256[2]));
    }

    /// @dev Get the number of different accounts that have been used to cast a ballot
    /// @return Number of accounts
    function getNumVoter() external view returns (uint256) {
        return voters.length;
    }

    /// @dev Get the address of a particular account used to cast a ballot
    /// @param i Index
    /// @return Account address
    function getVoter(uint256 i) external view returns (address) {
        return voters[i];
    }

    /// @dev Get the number of accounts used to cast ballots are invalidated by the authority
    /// @return Number of accounts
    function getNumNullVoter() external view returns (uint256) {
        return nullVoters.length;
    }

    /// @dev Get the address of a particular account used to cast an invalid ballot
    /// @param i Index
    /// @return Account address
    function getNullVoter(uint256 i) external view returns (address) {
        return nullVoters[i];
    }

    /// @dev Get a ballot stored in the contract indexed by the account address
    /// @param a account address
    /// @return h
    /// @return y
    /// @return zkp
    /// @return prefix
    function getBallot(address a)
        external
        view
        returns (
            uint256,
            uint256,
            uint256[8] memory,
            uint256
        )
    {
        require(checkBallot[a], "Ballot does not exist");

        return (ballots[a].h, ballots[a].y, ballots[a].zkp, ballots[a].prefix);
    }

    /// @dev Get the current state
    /// @return state: 0 - INIT; 1 - CAST; 2 - TALLY; 3 - END
    function getState() external view returns (uint8) {
        return uint8(state);
    }

    /// @dev Get the tally result
    /// @return #total
    /// @return #invalid
    /// @return #yes
    function getTallyRes()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(hasSetTallyRes, "Tally result not yet set");

        return (voters.length, nullVoters.length, tallyRes.V);
    }
}
