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

    // address private lib;

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
        uint256 y = EllipticCurve.deriveY(_gkPrefix, _gk, AA, BB, PP);

        require(
            EllipticCurve.isOnCurve(_gk, y, AA, BB, PP),
            "Invalid public key"
        );

        gk = _gk;
        gkPrefix = _gkPrefix;

        state = State.Cast;

        // emit RegAuthPubKey(_gk, _gkPrefix);
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
        if (!checkBallot[tx.origin]) {
            checkBallot[tx.origin] = true;
            voters.push(tx.origin);
        }

        ballots[tx.origin] = Ballot({h: h, y: y, zkp: zkp, prefix: prefix});
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
    function verifyBallot(address a) external view returns (bool) {
        require(checkBallot[a], "Ballot does not exist");

        uint256[4] memory params;
        uint256 prefix = ballots[a].prefix;

        params[0] = ballots[a].zkp[0];
        params[1] = ballots[a].zkp[1];
        params[2] = ballots[a].zkp[2];
        params[3] = ballots[a].zkp[3];

        return
            verifyBinaryZKP(
                a,
                getECPoint(ballots[a].h, getByteVal(prefix, 5)), // h
                getECPoint(ballots[a].y, getByteVal(prefix, 4)), // y
                params, // [d1, r1, d2, r2]
                getECPoint(ballots[a].zkp[4], getByteVal(prefix, 3)), // a1
                getECPoint(ballots[a].zkp[5], getByteVal(prefix, 2)), // b1
                getECPoint(ballots[a].zkp[6], getByteVal(prefix, 1)), // a2
                getECPoint(ballots[a].zkp[7], getByteVal(prefix, 0)) // b2
            );
    }

    /// @dev Verify the tally result after the tally is ended by the authority
    /// @return true or false
    function verifyTallyRes() external view inState(State.End) returns (bool) {
        require(hasSetTallyRes, "Tally result not yet set");

        // if there is no ballot cast
        if (voters.length == 0) {
            // the number of yes votes must be zero
            if (tallyRes.V != 0) {
                return false;
            }
            // stop the verification here, no need to go further
            return true;
        }

        if (!verifyHAndY()) {
            return false;
        }

        uint256[2] memory p;
        uint256[2] memory X;
        X = getECPoint(tallyRes.X, getByteVal(tallyRes.prefix, 3));
        uint256[2] memory Y;
        Y = getECPoint(tallyRes.Y, getByteVal(tallyRes.prefix, 2));

        // check Y = X * g^V
        (p[0], p[1]) = EllipticCurve.ecMul(tallyRes.V, GX, GY, AA, PP);
        (p[0], p[1]) = EllipticCurve.ecAdd(p[0], p[1], X[0], X[1], AA, PP);
        if (p[0] != Y[0] || p[1] != Y[1]) {
            return false;
        }

        return
            verifyECFSProof(
                auth,
                getECPoint(tallyRes.zkp[0], getByteVal(tallyRes.prefix, 1)),    // H
                X,                                                              // X
                getECPoint(tallyRes.zkp[1], getByteVal(tallyRes.prefix, 0)),    // t
                tallyRes.zkp[2]                                                 // r
            );
    }

    /// @dev Get authority public key
    /// @return Public key
    function getAuthPubKey() external view returns (uint256[2] memory) {
        return getECPoint(gk, gkPrefix);
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

    function getState() external view returns (uint8) {
        return uint8(state);
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
                ballots[a].h,
                EllipticCurve.deriveY(
                    getByteVal(ballots[a].prefix, 5),
                    ballots[a].h,
                    AA,
                    BB,
                    PP
                ),
                AA,
                PP
            );
            (_Y[0], _Y[1]) = EllipticCurve.ecAdd(
                _Y[0],
                _Y[1],
                ballots[a].y,
                EllipticCurve.deriveY(
                    getByteVal(ballots[a].prefix, 4),
                    ballots[a].y,
                    AA,
                    BB,
                    PP
                ),
                AA,
                PP
            );
        }

        if (
            _H[0] != tallyRes.zkp[0] ||
            _Y[0] != tallyRes.Y ||
            _H[1] !=
            EllipticCurve.deriveY(
                getByteVal(tallyRes.prefix, 1),
                tallyRes.zkp[0],
                AA,
                BB,
                PP
            ) ||
            _Y[1] !=
            EllipticCurve.deriveY(
                getByteVal(tallyRes.prefix, 2),
                tallyRes.Y,
                AA,
                BB,
                PP
            )
        ) {
            return false;
        }

        return true;
    }

    /// @dev Verify the zk proof proving that the encrypted value is either 1 or 0
    function verifyBinaryZKP(
        address data,
        uint256[2] memory h,
        uint256[2] memory y,
        uint256[4] memory params, // [d1, r1, d2, r2]
        uint256[2] memory a1,
        uint256[2] memory b1,
        uint256[2] memory a2,
        uint256[2] memory b2
    ) internal view returns (bool) {
        uint256[2] memory p1;
        uint256[2] memory p2;
        uint256[2] memory GK;
        GK = getECPoint(gk, gkPrefix);

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
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[1], GK[0], GK[1], AA, PP);
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
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[3], GK[0], GK[1], AA, PP);
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
        uint256[2] memory h,
        uint256[2] memory y,
        uint256[2] memory t,
        uint256 r
    ) internal pure returns (bool) {
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

    function getByteVal(uint256 b, uint256 i) internal pure returns (uint8) {
        return uint8((b >> (i * 8)) & 0xff);
    }

    function getECPoint(uint256 x, uint8 prefix)
        internal
        pure
        returns (uint256[2] memory)
    {
        uint256[2] memory p;
        p[0] = x;
        p[1] = EllipticCurve.deriveY(prefix, x, AA, BB, PP);

        return p;
    }
}
