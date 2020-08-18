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

    struct Ballot {
        uint256[2] h;
        uint256[2] y;
        uint256[4] params;
        uint256[2] a1;
        uint256[2] b1;
        uint256[2] a2;
        uint256[2] b2;
    }

    struct TallyRes {
        uint256 V;      // number of yes votes

        // Values from which V is computed
        uint256[2] X;   // X = H^k
        uint256[2] Y;   // Y = X * g^V

        // ECFS 
        uint256[2] H;   // H = prod_i h_i
        uint256[2] t;
        uint256 r;
    }

    // Authority
    address public auth;
    uint256 public gkX;
    uint256 public gkY;

    // Ballots
    address[] public voters;
    mapping(address => bool) checkVoter;
    mapping(address => Ballot) ballots;

    // Tally
    address[] public invalidBallots;
    mapping(address => bool) checkInvalidBallot;
    TallyRes tallyRes;

    enum State { Init, Cast, Tally, End }
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

    // Authority sets its public key and starts the casting period
    function setAuthPubKey(uint256 _gkX, uint256 _gkY)
        public
        onlyAuth
        inState(State.Init)
    {
        require(EllipticCurve.isOnCurve(_gkX, _gkY, AA, BB, PP), "Invalid public key");

        gkX = _gkX;
        gkY = _gkY;
        state = State.Cast;

        emit RegAuthPubKey(_gkX, _gkY);
    }

    // Due to high gas cost, ballots will be verified by the authority off-chain
    // Cast only save ballots
    function cast(
        uint256[2] memory _h,
        uint256[2] memory _y,
        uint256[4] memory _params,
        uint256[2] memory _a1,
        uint256[2] memory _b1,
        uint256[2] memory _a2,
        uint256[2] memory _b2
    ) 
        public
        inState(State.Cast) 
    {
        if(!checkVoter[msg.sender]) {
            checkVoter[msg.sender] = true;
            voters.push(msg.sender);
        }

        ballots[msg.sender] = Ballot({
            h:      _h,
            y:      _y,
            params: _params,
            a1:     _a1,
            b1:     _b1,
            a2:     _a2,
            b2:     _b2
        });

        emit Cast(msg.sender, keccak256(abi.encode(_h, _y)));
    }

    // Authority sets the addresses of the invalid ballots
    function invalidateBallots(address[] memory _invalidBallots) public onlyAuth() inState(State.Cast) {
        invalidBallots = _invalidBallots;

        for(uint i = 0; i < invalidBallots.length; i++) {
            checkInvalidBallot[invalidBallots[i]] = true;
        }

        state = State.Tally;
    }

    function tally(
        uint _V,
        uint256[2] memory _X,
        uint256[2] memory _Y,
        uint256[2] memory _H,
        uint256[2] memory _t,
        uint256 _r
    ) public onlyAuth() inState(State.Tally) {
        tallyRes = TallyRes({
            V:  _V, 
            X:  _X, 
            Y:  _Y, 
            H:  _H, 
            t:  _t, 
            r:  _r});

        emit Tally(_V, keccak256(abi.encodePacked(_X, _Y)));
    }

    function terminate() public onlyAuth() inState(State.Tally) {
        state = State.End;
    }

    // Verify the ballot cast by the input address
    function verifyBallot(address a) public view returns (bool) {
        require(checkVoter[a], "The input address hasn't cast a ballot");
        
        return verifyBinaryZKP(
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

    function totalValidBallots() public view returns (uint) {
        uint N = voters.length;
        for(uint i = 0; i < voters.length; i++) {
            if(checkInvalidBallot[voters[i]]) {
                N = N - 1;
            }
        }
        return N;
    }

    function verifyHAndY() public view returns (bool) {
        uint256[2] memory _H;
        uint256[2] memory _Y;
        address a;

        for(uint j=0; j < voters.length; j++) {
            a = voters[j];

            if(checkInvalidBallot[a]) {
                continue;
            }

            (_H[0], _H[1]) = EllipticCurve.ecAdd(_H[0], _H[1], ballots[a].h[0], ballots[a].h[1], AA, PP);
            (_Y[0], _Y[1]) = EllipticCurve.ecAdd(_Y[0], _Y[1], ballots[a].y[0], ballots[a].y[1], AA, PP);
        }

        if(_H[0] != tallyRes.H[0] || _H[1] != tallyRes.H[1] || 
           _Y[0] != tallyRes.Y[0] || _Y[1] != tallyRes.Y[1]) {
               return false;
        }
    }

    function verifyTallyRes() public view returns (bool) {
        uint256[2] memory p;
        
        // check Y = X * g^V
        (p[0], p[1]) = EllipticCurve.ecMul(tallyRes.V, GX, GY, AA, PP);
        (p[0], p[1]) = EllipticCurve.ecAdd(p[0], p[1], tallyRes.X[0], tallyRes.X[1], AA, PP);
        if(p[0] != tallyRes.Y[0] || p[1] != tallyRes.Y[1]) {
            return false;
        }

        return verifyECFSProof(
            auth,
            tallyRes.H,
            tallyRes.X,
            tallyRes.t,
            tallyRes.r
        );
    }

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

        // hash(msg.sender, ga, y, a1, b1, a2, b2) == d1 + d2 (mod n)
        if(uint256(sha256(abi.encodePacked(data, h, y, a1, b1, a2, b2))) != addmod(params[0], params[2], NN)) {
            return false;
        } 

        // a1 = g^{r1 + d1*a}
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[0], h[0], h[1], AA, PP);
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
        (p1[0], p1[1]) = EllipticCurve.ecMul(params[2], h[0], h[1], AA, PP);
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

    // ECFS - proving the knowledge of x s.t. h^x = y
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
        (p1[0], p1[1]) = EllipticCurve.ecAdd(p1[0], p1[1], p2[0], p2[1], AA, PP);
        if (p1[0] != t[0] || p1[1] != t[1]) {
            return false;
        }

        return true;
    }

    event RegAuthPubKey(uint256 indexed gkX, uint256 indexed gkY);
    event Cast(address indexed from, bytes32 indexed ballotHash);
    event Tally(uint256 indexed V, bytes32 indexed tallyHash);
}
