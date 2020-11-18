// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./BinaryVoteLib.sol";

/// @title Voting Contract
/// @author Peter Zhou
/// @dev Main contract used to conduct a privacy-preserved voting
contract VotingContractV2 {
    mapping(address => bytes32[]) public voteID;
    mapping(bytes32 => address) public voteAuth;
    mapping(bytes32 => uint256) public castEndTime;
    mapping(bytes32 => bytes32) public topics;
    mapping(bytes32 => bytes32) public optYes; 
    mapping(bytes32 => bytes32) public optNo;

    // number of votes created so far
    uint256 count;
    address lib;    

    /// @dev constructor
    /// @param _lib address of deployed BinaryVoteV2
    constructor(address _lib) {
        lib = _lib;
    }

    /// @dev Register a new vote
    function newBinaryVote(
        uint256 endTime, 
        bytes32 topicHash, 
        bytes32 yesHash, 
        bytes32 noHash
    ) external {
        require(endTime > block.timestamp, "Casting ending time must be in future");
        
        bytes32 id = keccak256(abi.encode(msg.sender, count));
        count = count + 1;

        voteID[msg.sender].push(id);
        voteAuth[id] = msg.sender;
        topics[id] = topicHash;
        optYes[id] = yesHash;
        optNo[id] = noHash;
        castEndTime[id] = endTime;

        BinaryVoteLib.DataStorage storage ds;
        assembly { ds.slot := id }

        ds.auth = msg.sender;
        ds.state = BinaryVoteLib.State.Init;
        ds.hasSetTallyRes = false;

        emit NewBinaryVote(id, msg.sender);
    }

    /// @dev Set public key by the authority
    /// @param id Vote ID
    /// @param _gk Public key
    function setAuthPubKey(
        bytes32 id,
        uint256 _gk,
        uint8 _gkPrefix
    ) external {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        (bool success, bytes memory _result) = lib.delegatecall(
            abi.encodeWithSignature(
                "setAuthPubKey(bytes32,uint256,uint8)",
                id,
                _gk,
                _gkPrefix
            )
        );

        require(success, "setAuthPubKey failed");
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
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        require(block.timestamp <= castEndTime[id], "Casting has ended");
        
        (bool success, bytes memory _result) = lib.delegatecall(
            abi.encodeWithSignature(
                "cast(bytes32,uint256,uint256,uint256[8],uint256)",
                id,
                h,
                y,
                zkp,
                prefix
            )
        );
        require(success, "cast failed");

        emit CastBinaryBallot(
            id,
            msg.sender,
            keccak256(
                abi.encode(h, getByteVal(prefix, 5), y, getByteVal(prefix, 4))
            )
        );
    }

    /// @dev Start tally by the authority
    /// @param id Vote ID
    function endTally(bytes32 id) external {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.auth == msg.sender, "Require authority account");
        require(ds.state == BinaryVoteLib.State.Tally, "Must be in state Tally");

        require(ds.hasSetTallyRes, "Tally result not yet set");

        ds.state = BinaryVoteLib.State.End;

        emit EndTally(id, msg.sender);
    }

    /// @dev Upload the tally result
    /// @param id Vote ID
    /// @param nulls addresses of the voters whose ballots are invalid
    /// @param V Total number of yes votes
    /// @param X prod_i(h_i)
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
    ) external {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        require(block.timestamp > castEndTime[id], "Casting has not yet ended");
        
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        if(ds.state == BinaryVoteLib.State.Cast) {
            ds.state = BinaryVoteLib.State.Tally;
        }

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

        emit SetTallyRes(
            id,
            msg.sender,
            V,
            keccak256(
                abi.encode(X, getByteVal(prefix, 3), Y, getByteVal(prefix, 2))
            )
        );
    }

    /// @dev Verify a cast ballot
    /// @param id Vote ID
    /// @param a address of the account used to cast the ballot
    /// @return true or false
    function verifyBallot(bytes32 id, address a) external returns (bool) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        
        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("verifyBallot(bytes32,address)", id, a)
        );
        require(success, "verifyBallot failed");

        return abi.decode(result, (bool));
    }

    /// @dev Verify the tally result
    /// @notice After the tally is ended by the authority
    /// @param id Vote ID
    /// @return true or false
    function verifyTallyRes(bytes32 id) external returns (bool) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.state == BinaryVoteLib.State.End, "Must be in state End");

        // Verify claimed invalid ballots
        uint256 n = ds.nullVoters.length;
        // address a;
        for (uint256 i = 0; i < n; i++) {
            // a = this.getNullVoter(id, i);
            if (this.verifyBallot(id, ds.nullVoters[i])) {
                return false;
            }
        }

        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("verifyTallyRes(bytes32)", id)
        );
        require(success, "verifyTallyRes failed");

        return abi.decode(result, (bool));
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
        returns (uint256[2] memory)
    {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        (bool success, bytes memory result) = lib.delegatecall(
            abi.encodeWithSignature("getAuthPubKey(bytes32)", id)
        );
        require(success, "getAuthPubKey failed");

        return abi.decode(result, (uint256[2]));
    }

    /// @dev Get the number of accounts used to cast ballots are invalidated by the authority
    /// @param id Vote ID
    /// @return Number of accounts
    function getNumNullVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.hasSetTallyRes, "Tally result not yet set");

        return ds.nullVoters.length;
    }

    /// @dev Get the address of a particular account used to cast an invalid ballot
    /// @param id Vote ID
    /// @param i Index
    /// @return Account address
    function getNullVoter(bytes32 id, uint256 i)
        external
        view
        returns (address)
    {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.hasSetTallyRes, "Tally result not yet set");
        require(i < ds.nullVoters.length, "Invalid index");

        return ds.nullVoters[i];
    }

    /// @dev Get the number of accounts used to cast ballots
    /// @param id Vote ID
    /// @return Number of accounts
    function getNumVoter(bytes32 id) external view returns (uint256) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        return ds.voters.length;
    }

    /// @dev Get the address of a particular account used to cast a ballot
    /// @param id Vote ID
    /// @param i Index
    /// @return Account address
    function getVoter(bytes32 id, uint256 i) external view returns (address) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(i < ds.voters.length, "Invalid index");
        
        return ds.voters[i];
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
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");
        
        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.checkBallot[a], "Ballot does not exist");

        return (ds.ballots[a].h, ds.ballots[a].y, ds.ballots[a].zkp, ds.ballots[a].prefix);
    }

    /// @dev Get the current state
    /// @param id vote id
    /// @return state: 0 - INIT; 1 - CAST; 2 - TALLY; 3 - END
    function getState(bytes32 id) external view returns (uint8) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        return uint8(ds.state);
    }

    /// @dev Get the tally result
    /// @param id vote id
    /// @return #total
    /// @return #invalid
    /// @return #yes
    function getTallyRes(bytes32 id) external view returns (uint256, uint256, uint256) {
        require(uint256(voteAuth[id]) > 0, "Vote ID does not exist");

        BinaryVoteLib.DataStorage storage ds;
        assembly{ ds.slot := id }

        require(ds.hasSetTallyRes, "Tally result not yet set");

        return (ds.voters.length, ds.nullVoters.length, ds.tallyRes.V);
    }

    function getByteVal(uint256 b, uint256 i) internal pure returns (uint8) {
        return uint8((b >> (i * 8)) & 0xff);
    }

    event NewBinaryVote(bytes32 indexed id, address indexed from);
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
