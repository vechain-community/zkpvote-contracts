import { utils } from 'myvetools'

const fs = require('fs')

const accounts: { privKey: string, pubKey: string }[] = [
    { privKey: '0x3e61996a0a49b26a5608a55a3e0669aff271959d2e43658766e3514a07a5ccf3', pubKey: '0xCDFDFD58e986130445B560276f52CE7985809238' },
    { privKey: '0xfb36f708acfd7e220634c4f48228fc5640c55575e5b2824047e4fa740bc5b532', pubKey: '0x17faD1428DC464187C33C5EfD281aE7E58937Fd8' },
    { privKey: '0x24c0f884abc45fc6013e38e0571c24fb0b2bcdd19493640a454d07ee57bf83dc', pubKey: '0xF9a0c98Aa23Bf75D46384B839620Ec2E9926DE7d' },
    { privKey: '0x5d6de2a70d5c8bffabf5010926d98e45dd5d98db55ca739104a092f5bf152deb', pubKey: '0xbd0A8dca41215d772b9cd6fB91696EcC9ac6a2D1' },
    { privKey: '0xec6aca0c3d926317040cc4f4f40385f7e38714ea529c77129f2e5cf6f174d3ed', pubKey: '0xbC985662CE20FD344Ea02dd92b208C2ab0eC78fd' },
    { privKey: '0xc052e95e1f99a601f0c39fdda813c74df50987dd4ef2b4fcb6a1b628edf6e61d', pubKey: '0x72752eb265000AF3D16bAE4D9a6312Dc84c65D41' },
    { privKey: '0x67bc06c668f9dac4b9e4850b395f84d7d2bf88951f785e191a0ddc0e55b70c86', pubKey: '0x9902a999FB8103B37bD11DB32a86E1ecf3FC12e6' },
    { privKey: '0xed0115126799073ccbd4b757a410805c2785b3da699881f35689aa934c896d8f', pubKey: '0xCA9d05b097cf7646ad641101bffE48022f842A2d' },
    { privKey: '0x82dbe83e281095d2011244f66e1f54a9c505ecb7036090390f909b5849cbcdee', pubKey: '0x20bb4844D2DBEA13053ca43B60b07Eae1b56e964' },
    { privKey: '0xd8fb043dfc25bb5ea4621668a69f954b6e9810f9c3075eef463fc6b40e5d8189', pubKey: '0x06Abf1999FC0E0A5C26784d8817Df99e7d13b2FC' },
];

const binVoteCreator = utils.getSolcBin('./contracts/VoteCreator.sol', 'VoteCreator')
const abiVoteCreator = JSON.parse(utils.getSolcABI('./contracts/VoteCreator.sol', 'VoteCreator'))

const binVotingContract = utils.getSolcBin('./contracts/VotingContract.sol', 'VotingContract')
const abiVotingContract = JSON.parse(utils.getSolcABI('./contracts/VotingContract.sol', 'VotingContract'))

const authPubKey = JSON.parse(fs.readFileSync('./test/data/auth-pub-key.json', 'utf8'))
const infoFile = './test/data/info.json'
const logFile = './test/data/log.txt'

const ballots = JSON.parse(fs.readFileSync('./test/data/bin-ballot.json', 'utf8'))
const tallyRes = JSON.parse(fs.readFileSync('./test/data/bin-tally-res.json', 'utf8'))
const invalidBallots = JSON.parse(fs.readFileSync('./test/data/invalid-bin-addr.json', 'utf8'))

export {
    accounts,
    binVoteCreator, abiVoteCreator,
    binVotingContract, abiVotingContract,
    authPubKey, 
    infoFile,
    ballots, tallyRes, invalidBallots
}