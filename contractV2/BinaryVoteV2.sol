// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./EllipticCurveV2.sol";
import "./BinaryVoteLib.sol";

/// @title Binary Vote Contract
/// @author Peter Zhou
/// @dev Implementation of a privacy-preserved voting protocol
/// @notice Curve p256 is implemented
/// @notice Support YES/NO ballots only
contract BinaryVoteV2 {
    // P245 curve constants
    uint256 constant GX = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    uint256 constant GY = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;
    uint256 constant PP = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff;
    uint256 constant NN = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551;
    uint256 constant AA = 0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc;
    uint256 constant BB = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b;

    /// @dev Set compressed public key by the authority
    /// @param id Vote ID
    /// @param _gk x coordinate
    /// @param _gkPrefix prefix
    function setAuthPubKey(bytes32 id, uint256 _gk, uint8 _gkPrefix)
        external
        // onlyAuth
        // inState(State.Init)
    {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.auth == msg.sender, "Require authority account");
        require(ds.state == BinaryVoteLib.State.Init, "Must be in state Init");

        uint256 y = EllipticCurve.deriveY(_gkPrefix, _gk, AA, BB, PP);

        require(
            EllipticCurve.isOnCurve(_gk, y, AA, BB, PP),
            "Invalid public key"
        );

        ds.gk = _gk;
        ds.gkPrefix = _gkPrefix;
        ds.state = BinaryVoteLib.State.Cast;
    }

    /// @dev Cast a yes/no ballot8
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
    ) 
        external 
        // inState(State.Cast) 
    {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.state == BinaryVoteLib.State.Cast, "Must be in state Cast");

        if (!ds.checkBallot[msg.sender]) {
            ds.checkBallot[msg.sender] = true;
            ds.voters.push(msg.sender);
        }

        ds.ballots[msg.sender] = BinaryVoteLib.Ballot({h: h, y: y, zkp: zkp, prefix: prefix});
    }

    /// @dev Upload the tally result
    /// @param id Vote ID
    /// @param nulls addresses of the voters whose ballots are invalid
    /// @param V Total number of yes votes
    /// @param X H^k
    /// @param Y prod_i(y_i)
    /// @param zkp proof of the knowedge of k; zkp = [H, t, r]
    /// @param prefix parity bytes (0x02 even, 0x03 odd) for compressed ec points X | Y | H | t
    function setTallyRes(
        bytes32 id,
        address[] calldata nulls,
        uint256 V,
        uint256 X,
        uint256 Y,
        uint256[3] calldata zkp,
        uint256 prefix
    ) 
        external 
        // onlyAuth() 
        // inState(State.Tally) 
    {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.auth == msg.sender, "Require authority account");
        require(ds.state == BinaryVoteLib.State.Tally, "Must be in state Tally");

        for (uint256 i = 0; i < nulls.length; i++) {
            address a = nulls[i];

            if (ds.checkBallot[a] && !ds.checkInvalidBallot[a]) {
                ds.checkInvalidBallot[a] = true;
                ds.nullVoters.push(a);
            }
        }

        ds.tallyRes = BinaryVoteLib.TallyRes({V: V, X: X, Y: Y, zkp: zkp, prefix: prefix});
        ds.hasSetTallyRes = true;
    }

    /// @dev Verify a cast ballot
    /// @param id Vote ID
    /// @param a address of the account used to cast the ballot
    /// @return true or false
    function verifyBallot(bytes32 id, address a) external view returns (bool) {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.checkBallot[a], "Ballot does not exist");

        uint256[4] memory params;
        uint256 prefix = ds.ballots[a].prefix;

        params[0] = ds.ballots[a].zkp[0];
        params[1] = ds.ballots[a].zkp[1];
        params[2] = ds.ballots[a].zkp[2];
        params[3] = ds.ballots[a].zkp[3];

        BinaryVoteLib.BinaryProof memory proof = BinaryVoteLib.BinaryProof({
            data: a,
            h: getECPoint(ds.ballots[a].h, getByteVal(prefix, 5)), // h
            y: getECPoint(ds.ballots[a].y, getByteVal(prefix, 4)), // y
            params: params, // [d1, r1, d2, r2]
            a1: getECPoint(ds.ballots[a].zkp[4], getByteVal(prefix, 3)), // a1
            b1: getECPoint(ds.ballots[a].zkp[5], getByteVal(prefix, 2)), // b1
            a2: getECPoint(ds.ballots[a].zkp[6], getByteVal(prefix, 1)), // a2
            b2: getECPoint(ds.ballots[a].zkp[7], getByteVal(prefix, 0))  // b2
        });

        return verifyBinaryZKP(id, proof);
    }

    /// @dev Verify the tally result after the tally is ended by the authority
    /// @param id Vote ID
    /// @return true or false
    function verifyTallyRes(bytes32 id) 
        external 
        view 
        // inState(State.End) 
        returns (bool) 
    {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.state == BinaryVoteLib.State.End, "Must be in state End");

        // if there is no ballot cast
        if (ds.voters.length == 0) {
            // the number of yes votes must be zero
            if (ds.tallyRes.V != 0) {
                return false;
            }
            // stop the verification here, no need to go further
            return true;
        }

        if (!verifyHAndY(id)) {
            return false;
        }

        uint256[2] memory p;
        uint256[2] memory X;
        X = getECPoint(ds.tallyRes.X, getByteVal(ds.tallyRes.prefix, 3));
        uint256[2] memory Y;
        Y = getECPoint(ds.tallyRes.Y, getByteVal(ds.tallyRes.prefix, 2));

        // check Y = X * g^V
        (p[0], p[1]) = EllipticCurve.ecMul(ds.tallyRes.V, GX, GY, AA, PP);
        (p[0], p[1]) = EllipticCurve.ecAdd(p[0], p[1], X[0], X[1], AA, PP);
        if (p[0] != Y[0] || p[1] != Y[1]) {
            return false;
        }

        return
            verifyECFSProof(
                ds.auth,
                getECPoint(ds.tallyRes.zkp[0], getByteVal(ds.tallyRes.prefix, 1)),  // H
                X,                                                                  // X
                getECPoint(ds.tallyRes.zkp[1], getByteVal(ds.tallyRes.prefix, 0)),  // t
                ds.tallyRes.zkp[2]                                                  // r
            );
    }

    /// @dev Get authority public key
    /// @param id Vote ID
    /// @return Public key
    function getAuthPubKey(bytes32 id) external view returns (uint256[2] memory) {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        return getECPoint(ds.gk, ds.gkPrefix);
    }

    /// @dev Verify H = prod_i(h_i) and Y = prod_i(y_i)
    /// @param id Vote ID
    /// @return true or false
    function verifyHAndY(bytes32 id) internal view returns (bool) {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        uint256[2] memory _H;
        uint256[2] memory _Y;
        address a;

        for (uint256 j = 0; j < ds.voters.length; j++) {
            a = ds.voters[j];

            if (ds.checkInvalidBallot[a]) {
                continue;
            }

            (_H[0], _H[1]) = EllipticCurve.ecAdd(
                _H[0],
                _H[1],
                ds.ballots[a].h,
                EllipticCurve.deriveY(
                    getByteVal(ds.ballots[a].prefix, 5),
                    ds.ballots[a].h,
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
                ds.ballots[a].y,
                EllipticCurve.deriveY(
                    getByteVal(ds.ballots[a].prefix, 4),
                    ds.ballots[a].y,
                    AA,
                    BB,
                    PP
                ),
                AA,
                PP
            );
        }

        if (
            _H[0] != ds.tallyRes.zkp[0] ||
            _Y[0] != ds.tallyRes.Y ||
            _H[1] !=
            EllipticCurve.deriveY(
                getByteVal(ds.tallyRes.prefix, 1),
                ds.tallyRes.zkp[0],
                AA,
                BB,
                PP
            ) ||
            _Y[1] !=
            EllipticCurve.deriveY(
                getByteVal(ds.tallyRes.prefix, 2),
                ds.tallyRes.Y,
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
    /// @param id Vote ID
    function verifyBinaryZKP(
        bytes32 id,
        BinaryVoteLib.BinaryProof memory p
    ) internal view returns (bool) {
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        uint256[2] memory p1;
        uint256[2] memory p2;
        uint256[2] memory GK;
        GK = getECPoint(ds.gk, ds.gkPrefix);

        // hash(data, ga, y, a1, b1, a2, b2) == d1 + d2 (mod n)
        if (
            uint256(sha256(abi.encodePacked(p.data, p.h, p.y, p.a1, p.b1, p.a2, p.b2))) !=
            addmod(p.params[0], p.params[2], NN)
        ) {
            return false;
        }

        // a1 = g^{r1 + d1*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(p.params[0], p.h[0], p.h[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(p.params[1], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != p.a1[0] || p1[1] != p.a1[1]) {
            return false;
        }

        // b1 = g^{k*r1} y^d1
        (p1[0], p1[1]) = EllipticCurve.ecMul(p.params[0], p.y[0], p.y[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(p.params[1], GK[0], GK[1], AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != p.b1[0] || p1[1] != p.b1[1]) {
            return false;
        }

        // a2 = g^{r2 + d2*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(p.params[2], p.h[0], p.h[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(p.params[3], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != p.a2[0] || p1[1] != p.a2[1]) {
            return false;
        }

        // b2 = g^{k*r2} (y/g)^d2
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p.y[0], p.y[1], GX, PP - GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecMul(p.params[2], p1[0], p1[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(p.params[3], GK[0], GK[1], AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(
            p2[0],
            p2[1],
            p1[0],
            p1[1],
            AA,
            PP
        );
        if (p1[0] != p.b2[0] || p1[1] != p.b2[1]) {
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
