pragma solidity >=0.5.3 <0.7.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/zkBinaryVote.sol";

contract TestZkBinaryVote {
    // function testIsOnCurve() public {
    //     ZkBinaryVote v = new ZkBinaryVote();

    //     uint256 x = 0xa1ea9fd679369c7ec082588bb390b996eba06b3a32c84b1b81cda0f4a2a4a33c;
    //     uint256 y = 0x82f96bdf0b1ca1144917dd18cdbe085badd968eba0520f66391d3a554840cdb0;

    //     bool expected = true;
    //     Assert.equal(v.isOnCurve(x,y), expected, "Should return true");
    // }

    function testVerifyCast() public {
        ZkBinaryVote v = new ZkBinaryVote();

        uint256 gkX = 0xf095f8554dd7324184a33cbd32d7fa367435be2342fea1eb4d9341345ab69c63;
        uint256 gkY = 0xd3023699c853a13cbfed76d3d91533332913d75df9ca737d3c60eb3ef2edaad2;
        v.setAuthPubKey(gkX, gkY);

        // [d1, r1, d2, r2] 
        uint256[4] memory params = [
            0x7107e9accf61797d97eca2a0f089c674d3f1c72d5aadaf026d6829cde20fe7cc, 0x7e35a81e22768f5676fe5d0f58dc88551c936cd76d80b6070a8018ea5b4c0e3c,
            0xbdc7668d1303ec4a802fe2d11a5009422cc93e118c4571bfd86663ad7cee7f1d, 
            0x00a6e5d2663db1b509ccc541b93444bb5ec945952068acdb98defdd09f9da319
        ];

        uint256[2] memory ga = [
            0xa45b9a5338e06ea3d42528928fff207af5b9030da5220c4c42252de7e21a3117,
            0x241faf273be427baffc8bf6798154618feaecf7c9d4e718f2802c4aa0f8d72c6
        ];

        uint256[2] memory y = [
            0xab324e8705a3d3b12908040da78875aa7b9342fe6058deeaff32e127f5714c58,
            0x6722ca2000e2a9963a1d5a77bbba70e794a12214234862f09505762d7199578b
        ];

        uint256[2] memory a1 = [
            0xc71a5cd15c0401ac15258ef9dd01f50987ab252f9ce270188127552efe06b7b5,
            0x4065f0f19389defca7543bd4e13a118d9b59b89b09ce55eae20ea88b8613c4a6
        ];

        uint256[2] memory b1 = [
            0x1aa0bcbd0b65b86704fb39839273587026ebdb7078eac94fda9bb21628cdf993,
            0x8b9a8ca48d1968fd0f79c5c11abb0948c06de67829d797f0135a0a8b6211c9a4
        ];

        uint256[2] memory a2 = [
            0xc86d285ebc4087bd20293987cb9a0c1a18275135ce1bd4656e9ec4ff0427b72c,
            0x9dd981dba3dbc4ac46ba7707e590ff1fdf07694d736681873471195c7a2508ba
        ];

        uint256[2] memory b2 = [
            0xdb686e38e8a22c4588b05153c3bb437cf8343ed7a77f6ab1b603a226f2004246,
            0x39bc364ed1ebff38dee780e9194b97a43b6f6d59ba5286ddbd6396bccd72f06e
        ];

        bool b = v.verifyBinaryZKProof(params, ga, y, a1, b1, a2, b2);
        Assert.equal(b, true, "test failed");
    }
}
