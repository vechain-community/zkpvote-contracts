// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library BinaryVoteLib {
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

    enum State {
        Init,
        Cast, // start after authority sets the public key
        Tally, // start after authority calls function beginTally()
        End // ends after authority calls function endTally()
    }

    struct BinaryProof {
        address data;
        uint256[2] h;
        uint256[2] y;
        uint256[4] params; // [d1, r1, d2, r2]
        uint256[2] a1;
        uint256[2] b1;
        uint256[2] a2;
        uint256[2] b2;
    }

    struct DataStorage {
        // Authority
        address auth; // account address
        uint8 gkPrefix;
        uint256 gk; // authority-generated public key

        // Ballots
        address[] voters; // addresses of the accounts that have cast a ballot
        mapping(address => bool) checkBallot; // mapping used to check whether an account has cast a ballot
        mapping(address => Ballot) ballots;
        
        // Tally
        address[] nullVoters; // addresses of the accounts that have cast an invalid ballot
        mapping(address => bool) checkInvalidBallot; // mapping used to check whether an account has cast an invalid ballot
        TallyRes tallyRes; // outputs of the tally carried by authority off-chain
        bool hasSetTallyRes;
        
        // State
        State state;
    }
}
