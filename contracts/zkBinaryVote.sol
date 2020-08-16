pragma solidity >=0.5.3 <0.7.0;

import "./EllipticCurve.sol";

contract ZkBinaryVote {
    uint256
        public constant GX = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    uint256
        public constant GY = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;
    uint256
        public constant PP = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff;
    uint256
        public constant NN = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551;
    uint256
        public constant AA = 0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc;
    uint256
        public constant BB = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b;

    uint256 public HX;
    uint256 public HY;
    uint256 public YX;
    uint256 public YY;

    mapping(address => bool) public voted;

    address public auth;
    uint256 public gkX;
    uint256 public gkY;

    enum State {Init, Cast, Tally, End}
    State public state;

    modifier onlyAuth() {
        // Modifier
        require(msg.sender == auth, "Only authority can call this.");
        _;
    }

    modifier inState(State _state) {
        require(state == _state, "Invalid state.");
        _;
    }

    constructor() public {
        auth = msg.sender;
        state = State.Init;
    }

    function setAuthPubKey(uint256 x, uint256 y)
        public
        onlyAuth
        inState(State.Init)
    {
        require(EllipticCurve.isOnCurve(x, y, AA, BB, PP), "Invalid public key");

        gkX = x;
        gkY = y;
        state = State.Cast;
    }

    // function isOnCurve(uint256 x, uint256 y) public pure returns (bool) {
    //     return EllipticCurve.isOnCurve(x, y, AA, BB, PP);
    // }

    function verifyBinaryZKProof(
        uint256[4] memory params, // [d1, r1, d2, r2]
        uint256[2] memory ga,
        uint256[2] memory y,
        uint256[2] memory a1,
        uint256[2] memory b1,
        uint256[2] memory a2,
        uint256[2] memory b2
    ) public view returns (bool) {

        uint256[2] memory p1;
        uint256[2] memory p2;

        // a1 = g^{r1 + d1*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[0], ga[0], ga[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[1], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p2[0], p2[1], p1[0], p1[1], AA, PP);
        if (p1[0] != a1[0] || p1[1] != a1[1]) {
            return false;
        }

        // b1 = g^{k*r1} y^d1
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[0], y[0], y[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[1], gkX, gkY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p2[0], p2[1], p1[0], p1[1], AA, PP);
        if (p1[0] != b1[0] || p1[1] != b1[1]) {
            return false;
        }

        // a2 = g^{r2 + d2*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[2], ga[0], ga[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[3], GX, GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p2[0], p2[1], p1[0], p1[1], AA, PP);
        if (p1[0] != a2[0] || p1[1] != a2[1]) {
            return false;
        }

        // b2 = g^{k*r2} (y/g)^d2
        (p1[0], p1[1]) = EllipticCurve.ecAdd(y[0], y[1], GX, PP - GY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[2], p1[0], p1[1], AA, PP);
        (p2[0], p2[1]) = EllipticCurve.ecMul(params[3], gkX, gkY, AA, PP);
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p2[0], p2[1], p1[0], p1[1], AA, PP);
        if (p1[0] != b2[0] || p1[1] != b2[1]) {
            return false;
        }

        return true;
    }
}
