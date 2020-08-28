pragma solidity >=0.5.3 <0.7.0;

import "./EllipticCurve.sol";

/// @author Peter Zhou
/// @title Contract for realizing a yes/no vote 
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

    // Authority
    address auth; // account address
    uint256[2] gk; // authority-generated public key

    // Ballots
    address[] voters; // addresses of the accounts that have cast a ballot
    mapping(address => bool) checkBallot; // mapping used to check whether an account has cast a ballot
    mapping(address => Ballot) ballots;

    // Data uploaded by authority
    address[] nullVoters; // addresses of the accounts that have cast an invalid ballot
    mapping(address => bool) checkInvalidBallot; // mapping used to check whether an account has cast an invalid ballot
    TallyRes tallyRes; // outputs of the tally carried by authority off-chain

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

    constructor() public {
        auth = tx.origin;
        state = State.Init;
    }

    /// Set public key by the authority
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

    /// Cast a yes/no ballot
    /// @param _h g^a
    /// @param _y (g^ka)(g^v) v\in{0,1}
    /// @param _params part of the zk proof
    /// @param _a1 part of the zk proof
    /// @param _b1 part of the zk proof
    /// @param _a2 part of the zk proof
    /// @param _b2 part of the zk proof
    function cast(
        uint256[2] calldata _h,
        uint256[2] calldata _y,
        uint256[4] calldata _params,
        uint256[2] calldata _a1,
        uint256[2] calldata _b1,
        uint256[2] calldata _a2,
        uint256[2] calldata _b2
    ) external inState(State.Cast) {
        if (!checkBallot[tx.origin]) {
            checkBallot[tx.origin] = true;
            voters.push(tx.origin);
        }

        ballots[tx.origin] = Ballot({
            h: _h,
            y: _y,
            params: _params,
            a1: _a1,
            b1: _b1,
            a2: _a2,
            b2: _b2
        });

        emit Cast(tx.origin, keccak256(abi.encode(_h, _y)));
    }

    /// Start tally by the authority
    function beginTally() external onlyAuth() inState(State.Cast) {
        state = State.Tally;
    }

    /// End tally by the authority
    function endTally() external onlyAuth() inState(State.Tally) {
        state = State.End;
    }

    /// Upload the tally result
    /// @param _nullVoters addresses of the voters whose ballots are invalid
    /// @param _V Total number of yes votes
    /// @param _X prod_i(h_i) 
    /// @param _Y prod_i(y_i)
    /// @param _H part of the zk proof
    /// @param _t part of the zk proof
    /// @param _r part of the zk proof
    function setTallyRes(
        address[] calldata _nullVoters,
        uint256 _V,
        uint256[2] calldata _X,
        uint256[2] calldata _Y,
        uint256[2] calldata _H,
        uint256[2] calldata _t,
        uint256 _r
    ) external onlyAuth() inState(State.Tally) {
        for (uint256 i = 0; i < _nullVoters.length; i++) {
            address a = _nullVoters[i];

            if (checkBallot[a] && !checkInvalidBallot[a]) {
                checkInvalidBallot[a] = true;
                nullVoters.push(a);
            }
        }

        tallyRes = TallyRes({V: _V, X: _X, Y: _Y, H: _H, t: _t, r: _r});

        emit Tally(_V, keccak256(abi.encode(_X, _Y)));
    }

    /// Verify a cast ballot
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

    /// Verify the tally result after the tally is ended by the authority
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

    /// Get authority public key
    /// @return Public key
    function getAuthPubKey() external view returns (uint256[2] memory) {
        return gk;
    }
    
    /// Get the number of different accounts that have been used to cast a ballot
    /// @return Number of accounts
    function getNumVoter() external view returns (uint256) {
        return voters.length;
    }

    /// Get the address of a particular account used to cast a ballot
    /// @param i Index
    /// @return Account address
    function getVoter(uint256 i) external view returns (address) {
        return voters[i];
    }

    /// Get the number of accounts used to cast ballots are invalidated by the authority
    /// @return Number of accounts
    function getNumNullVoter() external view returns (uint256) {
        return nullVoters.length;
    }

    /// Get the address of a particular account used to cast an invalid ballot
    /// @param i Index
    /// @return Account address
    function getNullVoter(uint256 i) external view returns (address) {
        return nullVoters[i];
    }

    /// Get a ballot stored in the contract indexed by the account address
    /// @param a account address
    /// @return ballot data
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

    /// Get the total number of valid ballots stored in the contact
    /// @return total number
    function getValidBallotNum()
        external
        view
        inState(State.End)
        returns (uint256)
    {
        return voters.length - nullVoters.length;
    }

    /// Verify H = prod_i(h_i) and Y = prod_i(y_i)
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

    /// Verify the zk proof within a ballot. The proof is used to prove that
    /// the encrypted value in the ballot is either 0 (NO) or 1 (YES).
    /// @param data address of the account used to cast the ballot
    /// @param h
    /// @param y
    /// @param params
    /// @param a1
    /// @param b1
    /// @param a2
    /// @param b2
    /// @return true or false
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

    /// Verify the zk proof within the tally result. The proof is used to prove that
    /// who uploads the tally result knows the private key associated with authority's 
    /// public key. 
    /// @param data address of the account the authority uses to interact with the cotract
    /// @param h
    /// @param y
    /// @param t
    /// @param r
    /// @return true or false
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
