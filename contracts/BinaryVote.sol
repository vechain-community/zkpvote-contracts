pragma solidity >=0.5.3 <0.7.0;

import "./EllipticCurve.sol";

/// @title Binary Vote Contract
/// @author Peter Zhou
/// @dev Implementation of a privacy-preserved voting protocol 
/// @notice Curve p256 is implemented
/// @notice Support YES/NO ballots only 
contract BinaryVote {
    // P245 curve constants
    uint256 constant GX = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    uint256 constant GY = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;
    uint256 constant PP = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff;
    uint256 constant NN = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551;
    uint256 constant AA = 0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc;
    uint256 constant BB = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b;

    // content of a ballot
    struct Ballot {
        uint256[2] h; // public key
        uint256[2] y; // encrypted vote
        // binary zkp proof
        uint256[4] params;
        uint256[2] a1;
        uint256[2] b1;
        uint256[2] a2;
        uint256[2] b2;
    }

    struct TallyRes {
        uint256 V; // number of yes votes
        // Values from which V is computed and to be verified
        uint256[2] X; // X = H^k
        uint256[2] Y; // Y = X * g^V
        // ECFS proof
        uint256[2] H; // H = prod_i h_i
        uint256[2] t;
        uint256 r;
    }

    // address private lib;

    // Authority
    address private auth; // account address
    uint256[2] private gk; // authority-generated public key

    // Ballots
    address[] private voters; // addresses of the accounts that have cast a ballot
    mapping(address => bool) private checkBallot; // mapping used to check whether an account has cast a ballot
    mapping(address => Ballot) private ballots;

    // Data uploaded by authority
    address[] private nullVoters; // addresses of the accounts that have cast an invalid ballot
    mapping(address => bool) private checkInvalidBallot; // mapping used to check whether an account has cast an invalid ballot
    TallyRes private tallyRes; // outputs of the tally carried by authority off-chain

    enum State {
        Init,
        Cast, // start after authority sets the public key
        Tally, // start after authority calls function beginTally()
        End // ends after authority calls function endTally()
    }
    State state;

    modifier onlyAuth() {
        // Modifier
        require(tx.origin == auth, "Only authority can call this.");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state");
        _;
    }

    modifier afterState(State _state) {
        require(state > _state, "Invalid state");
        _;
    }

    modifier beforeState(State _state) {
        require(state < _state, "Invalid state");
        _;
    }

    // constructor(address _lib) public {
    //     require(uint256(_lib) > 0, "Invalid EC library address");

    //     auth = tx.origin;
    //     lib = _lib;
    //     state = State.Init;
    // }
    constructor() public {
        auth = tx.origin;
        state = State.Init;
    }

    /// @dev Set public key by the authority
    /// @param _gk Public key
    function setAuthPubKey(uint256[2] calldata _gk)
        external
        onlyAuth
        inState(State.Init)
    {
        require(
            EllipticCurve.isOnCurve(_gk[0], _gk[1], AA, BB, PP),
            "Invalid public key"
        );

        gk = _gk;
        state = State.Cast;

        emit RegAuthPubKey(_gk[0], _gk[1]);
    }

    /// @dev Cast a yes/no ballot
    /// @param h g^a
    /// @param y (g^ka)(g^v) v\in{0,1}
    /// @param params [d1,r1,d2,r2]
    /// @param a1 a1
    /// @param b1 b1
    /// @param a2 a2
    /// @param b2 b2
    function cast(
        uint256[2] calldata h,
        uint256[2] calldata y,
        uint256[4] calldata params,
        uint256[2] calldata a1,
        uint256[2] calldata b1,
        uint256[2] calldata a2,
        uint256[2] calldata b2
    ) external inState(State.Cast) {
        if (!checkBallot[tx.origin]) {
            checkBallot[tx.origin] = true;
            voters.push(tx.origin);
        }

        ballots[tx.origin] = Ballot({
            h: h,
            y: y,
            params: params,
            a1: a1,
            b1: b1,
            a2: a2,
            b2: b2
        });

        emit Cast(tx.origin, keccak256(abi.encode(h, y)));
    }

    /// @dev Start tally by the authority
    function beginTally() external onlyAuth() inState(State.Cast) {
        state = State.Tally;
    }

    /// @dev End tally by the authority
    function endTally() external onlyAuth() inState(State.Tally) {
        state = State.End;
    }

    /// @dev Upload the tally result
    /// @param nulls addresses of the voters whose ballots are invalid
    /// @param V Total number of yes votes
    /// @param X H^k 
    /// @param Y prod_i(y_i)
    /// @param H prod_i(h_i)
    /// @param t t
    /// @param r r
    function setTallyRes(
        address[] calldata nulls,
        uint256 V,
        uint256[2] calldata X,
        uint256[2] calldata Y,
        uint256[2] calldata H,
        uint256[2] calldata t,
        uint256 r
    ) external onlyAuth() inState(State.Tally) {
        for (uint256 i = 0; i < nulls.length; i++) {
            address a = nulls[i];

            if (checkBallot[a] && !checkInvalidBallot[a]) {
                checkInvalidBallot[a] = true;
                nullVoters.push(a);
            }
        }

        tallyRes = TallyRes({V: V, X: X, Y: Y, H: H, t: t, r: r});

        emit Tally(V, keccak256(abi.encode(X, Y)));
    }

    /// @dev Verify a cast ballot
    /// @param a address of the account used to cast the ballot
    /// @return true or false
    function verifyBallot(address a) external view returns (bool) {
        require(checkBallot[a], "Ballot does not exist");

        return
            verifyBinaryZKP(
                a,
                ballots[a].h,
                ballots[a].y,
                ballots[a].params,
                ballots[a].a1,
                ballots[a].b1,
                ballots[a].a2,
                ballots[a].b2
            );
    }

    /// @dev Verify the tally result after the tally is ended by the authority
    /// @return true or false
    function verifyTallyRes() external view inState(State.End) returns (bool) {
        if (!verifyHAndY()) {
            return false;
        }

        uint256[2] memory p;

        // check Y = X * g^V
        (p[0], p[1]) = EllipticCurve.ecMul(tallyRes.V, GX, GY, AA, PP);
        (p[0], p[1]) = EllipticCurve.ecAdd(
            p[0],
            p[1],
            tallyRes.X[0],
            tallyRes.X[1],
            AA,
            PP
        );
        if (p[0] != tallyRes.Y[0] || p[1] != tallyRes.Y[1]) {
            return false;
        }

        return
            verifyECFSProof(
                auth,
                tallyRes.H,
                tallyRes.X,
                tallyRes.t,
                tallyRes.r
            );
    }

    /// @dev Get authority public key
    /// @return Public key
    function getAuthPubKey() external view returns (uint256[2] memory) {
        return gk;
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
    /// @return params
    /// @return a1
    /// @return b1
    /// @return a2
    /// @return b2
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
        )
    {
        require(checkBallot[a], "Ballot does not exist");

        return (
            ballots[a].h,
            ballots[a].y,
            ballots[a].params,
            ballots[a].a1,
            ballots[a].b1,
            ballots[a].a2,
            ballots[a].b2
        );
    }

    /// @dev Get the total number of valid ballots stored in the contact
    /// @return total number
    function getValidBallotNum()
        external
        view
        inState(State.End)
        returns (uint256)
    {
        return voters.length - nullVoters.length;
    }

    /// @dev Verify H = prod_i(h_i) and Y = prod_i(y_i)
    /// @return true or false
    function verifyHAndY() internal view returns (bool) {
        uint256[2] memory _H;
        uint256[2] memory _Y;
        address a;

        for (uint256 j = 0; j < voters.length; j++) {
            a = voters[j];

            if (checkInvalidBallot[a]) {
                continue;
            }

            (_H[0], _H[1]) = EllipticCurve.ecAdd(
                _H[0],
                _H[1],
                ballots[a].h[0],
                ballots[a].h[1],
                AA,
                PP
            );
            (_Y[0], _Y[1]) = EllipticCurve.ecAdd(
                _Y[0],
                _Y[1],
                ballots[a].y[0],
                ballots[a].y[1],
                AA,
                PP
            );
        }

        if (
            _H[0] != tallyRes.H[0] ||
            _H[1] != tallyRes.H[1] ||
            _Y[0] != tallyRes.Y[0] ||
            _Y[1] != tallyRes.Y[1]
        ) {
            return false;
        }

        return true;
    }

    /// @dev Verify the zk proof proving that the encrypted value is either 1 or 0
    function verifyBinaryZKP(
        address data,
        uint256[2] storage h,
        uint256[2] storage y,
        uint256[4] storage params, // [d1, r1, d2, r2]
        uint256[2] storage a1,
        uint256[2] storage b1,
        uint256[2] storage a2,
        uint256[2] storage b2
    ) internal view returns (bool) {
        uint256[2] memory p1;
        uint256[2] memory p2;

        // hash(data, ga, y, a1, b1, a2, b2) == d1 + d2 (mod n)
        if (
            uint256(sha256(abi.encodePacked(data, h, y, a1, b1, a2, b2))) !=
            addmod(params[0], params[2], NN)
        ) {
            return false;
        }

        // a1 = g^{r1 + d1*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[0], h[0], h[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[1], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != a1[0] || p1[1] != a1[1]) {
            return false;
        }

        // b1 = g^{k*r1} y^d1
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[0], y[0], y[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[1], gk[0], gk[1], AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != b1[0] || p1[1] != b1[1]) {
            return false;
        }

        // a2 = g^{r2 + d2*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[2], h[0], h[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[3], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != a2[0] || p1[1] != a2[1]) {
            return false;
        }

        // b2 = g^{k*r2} (y/g)^d2
        (p1[0], p1[1]) = EllipticCurve.ecAdd(y[0], y[1], GX, PP - GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[2], p1[0], p1[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[3], gk[0], gk[1], AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != b2[0] || p1[1] != b2[1]) {
            return false;
        }

        return true;
    }

    /// @dev Verify the zk proof proving the knowledge of authority private key 
    function verifyECFSProof(
        address data,
        uint256[2] storage h,
        uint256[2] storage y,
        uint256[2] storage t,
        uint256 r
    ) internal view returns (bool) {
        uint256[2] memory p1;
        uint256[2] memory p2;

        uint256 c = uint256(sha256(abi.encodePacked(data, h, y, t)));

        // check t = (h^r)(y^c)
        (p1[0], p1[1]) = EllipticCurve.ecMul(r, h[0], h[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(c, y[0], y[1], AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p1[0],
            p1[1],
            p2[0],
            p2[1],
            AA,
            PP
        );
        if (p1[0] != t[0] || p1[1] != t[1]) {
            return false;
        }

        return true;
    }

    event RegAuthPubKey(uint256 indexed gkX, uint256 indexed gkY);
    event Cast(address indexed from, bytes32 indexed ballotHash);
    event Tally(uint256 indexed V, bytes32 indexed tallyHash);
}
