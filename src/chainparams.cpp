// Copyright (c) 2010 Satoshi Nakamoto
// Copyright (c) 2009-2020 The Bitcoin Core developers
// Copyright (c) 2025 The Aegisum Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <chainparams.h>
#include <chainparamsseeds.h>
#include <consensus/merkle.h>
#include <hash.h> // for signet block challenge hash
#include <tinyformat.h>
#include <util/system.h>
#include <util/strencodings.h>
#include <versionbitsinfo.h>

#include <assert.h>

#include <boost/algorithm/string/classification.hpp>
#include <boost/algorithm/string/split.hpp>

static CBlock CreateGenesisBlock(const char* pszTimestamp, const CScript& genesisOutputScript, uint32_t nTime, uint32_t nNonce, uint32_t nBits, int32_t nVersion, const CAmount& genesisReward)
{
    CMutableTransaction txNew;
    txNew.nVersion = 1;
    txNew.vin.resize(1);
    txNew.vout.resize(1);
    txNew.vin[0].scriptSig = CScript() << 486604799 << CScriptNum(4) << std::vector<unsigned char>((const unsigned char*)pszTimestamp, (const unsigned char*)pszTimestamp + strlen(pszTimestamp));
    txNew.vout[0].nValue = genesisReward;
    txNew.vout[0].scriptPubKey = genesisOutputScript;

    CBlock genesis;
    genesis.nTime    = nTime;
    genesis.nBits    = nBits;
    genesis.nNonce   = nNonce;
    genesis.nVersion = nVersion;
    genesis.vtx.push_back(MakeTransactionRef(std::move(txNew)));
    genesis.hashPrevBlock.SetNull();
    genesis.hashMerkleRoot = BlockMerkleRoot(genesis);
    return genesis;
}

/**
 * Build the genesis block. Note that the output of its generation
 * transaction cannot be spent since it did not originally exist in the
 * database.
 *
 * CBlock(hash=000000000019d6, ver=1, hashPrevBlock=00000000000000, hashMerkleRoot=4a5e1e, nTime=1231006505, nBits=1d00ffff, nNonce=2083236893, vtx=1)
 *   CTransaction(hash=4a5e1e, ver=1, vin.size=1, vout.size=1, nLockTime=0)
 *     CTxIn(COutPoint(000000, -1), coinbase 04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73)
 *     CTxOut(nValue=50.00000000, scriptPubKey=0x5F1DF16B2B704C8A578D0B)
 *   vMerkleTree: 4a5e1e
 */
static CBlock CreateGenesisBlock(uint32_t nTime, uint32_t nNonce, uint32_t nBits, int32_t nVersion, const CAmount& genesisReward)
{
    const char* pszTimestamp = "Aegisum protects from crypto rugs and supports real causes";
    const CScript genesisOutputScript = CScript() << ParseHex("0453295f892e370afd15bf6b74a4f2cfd38102589b7f73475b9719e339cfa6d76f2a1adae3e860ca676118b95fb43efa21ddd205f797f310a10f1846cc0d3e6f4b") << OP_CHECKSIG;
    return CreateGenesisBlock(pszTimestamp, genesisOutputScript, nTime, nNonce, nBits, nVersion, genesisReward);
}

/**
 * Main network
 */
class CMainParams : public CChainParams {
public:
    CMainParams() {
        strNetworkID = CBaseChainParams::MAIN;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nSubsidyHalvingInterval = 100000;
        consensus.BIP16Height = 0; 
        consensus.BIP34Height = 0;
        consensus.BIP34Hash = uint256();
        consensus.BIP65Height = 0; 
        consensus.BIP66Height = 0; 
        consensus.CSVHeight = 0; 
        consensus.SegwitHeight = 0; 
        consensus.MinBIP9WarningHeight = 0; // segwit activation height + miner confirmation window
        consensus.powLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");

        // Original parameters (blocks 0-44999)
        consensus.nPowTargetTimespan = 9 * 60;  // 9 minutes
        consensus.nPowTargetSpacing = 3 * 60;   // 3 minutes per block
        consensus.nMinerConfirmationWindow = 12; // nPowTargetTimespan / nPowTargetSpacing * 4

        // Activation heights
        consensus.nDifficultyChangeActivationHeight = 21000; // Activate new difficulty rules at block (this helped, but wasn't perfect)
        consensus.nOneBlockRetargetActivationHeight = 51000; // Activate 1-block retarget

        // New parameters for 1-block retarget
        consensus.nPowTargetTimespanOneBlock = 3 * 60;  // 3 minutes for 1-block retarget
        consensus.nMinerConfirmationWindowOneBlock = 4; // (3*60)/(3*60) * 4 = 1 * 4 = 4

        // Emergency difficulty reset parameters (active after 1-block retarget)
        consensus.nEmergencyDifficultyResetTime = 30 * 60; // 30 minutes
        consensus.fAllowEmergencyDifficultyReset = true;   // Enable emergency reset

        consensus.fPowAllowMinDifficultyBlocks = false;
        consensus.fPowNoRetargeting = false;
        consensus.nRuleChangeActivationThreshold = 2; // 75% of 3

        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;

        // Deployment of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::ALWAYS_ACTIVE; 
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT; 

        // Deployment of MWEB (LIP-0002, LIP-0003, and LIP-0004)
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].bit = 4;
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE; 
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT; 

        // Updated minimum chain work for block 39300
        consensus.nMinimumChainWork = uint256S("0x00000000000000000000000000000000000000000000000028cef1aeb24c5835");
        // Updated assume valid hash for block 39300
        consensus.defaultAssumeValid = uint256S("0xab32b64b1f4a4ef9e32e8fb0cbcab1ef70c8126efa56c9261cf0a3511f628d3a"); 

        /**
         * The message start string is designed to be unlikely to occur in normal data.
         * The characters are rarely used upper ASCII, not valid as UTF-8, and produce
         * a large 32-bit integer with any alignment.
         */
        pchMessageStart[0] = 0xef;
        pchMessageStart[1] = 0x08;
        pchMessageStart[2] = 0xfe;
        pchMessageStart[3] = 0x61;
        nDefaultPort = 39941;
        nPruneAfterHeight = 100000;
        m_assumed_blockchain_size = 5;
        m_assumed_chain_state_size = 5;

        genesis = CreateGenesisBlock(1738496549, 128229, 0x1e0ffff0, 1, 500 * COIN);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0xd01de46801bba7913c039b4feabb42878e0a3e24ceef2365ed2a8d780c5aa9cd"));
        assert(genesis.hashMerkleRoot == uint256S("0x3b4a2bfc695933af8c87bb1a30e0719cbb2a22cb13b74f7a624ab3eb92d2d1d2"));

        // Note that of those which support the service bits prefix, most only support a subset of
        // possible options.
        // This is fine at runtime as we'll fall back to using them as an addrfetch if they don't support the
        // service bits we want, but we should get them updated to support all service bits wanted by any
        // release ASAP to avoid it where possible.
        vSeeds.emplace_back("node.aegisum.com");

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,24);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,5);
        base58Prefixes[SCRIPT_ADDRESS2] = std::vector<unsigned char>(1,23);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,151);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x88, 0xB2, 0x1E};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x88, 0xAD, 0xE4};

        bech32_hrp = "aegs";
        mweb_hrp = "aegsmweb";

        fDefaultConsistencyChecks = false;
        fRequireStandard = true;
        m_is_test_chain = false;
        m_is_mockable_chain = false;

        checkpointData = {
            {
                {  0, uint256S("0xd01de46801bba7913c039b4feabb42878e0a3e24ceef2365ed2a8d780c5aa9cd")},
                {  21500, uint256S("6279d38d109d596a75b51c8cc90d01e26dc02244156db58106431be71bec768f")},
                {  39300, uint256S("0xab32b64b1f4a4ef9e32e8fb0cbcab1ef70c8126efa56c9261cf0a3511f628d3a")},
            }
        };

        chainTxData = ChainTxData{
            // Data from rpc: getchaintxstats 4096 ab32b64b1f4a4ef9e32e8fb0cbcab1ef70c8126efa56c9261cf0a3511f628d3a
            /* nTime    */ 1752382792,  // timestamp from block 39300
            /* nTxCount */ 65501,       // actual total transaction count
            /* dTxRate  */ 0.009195741863189527  // actual transaction rate
        };
    }
};

/**
 * Testnet (v3)
 */
class CTestNetParams : public CChainParams {
public:
    CTestNetParams() {
        strNetworkID = CBaseChainParams::TESTNET;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nSubsidyHalvingInterval = 100000;
        consensus.BIP16Height = 0; // always enforce P2SH BIP16 on testnet
        consensus.BIP34Height = 76;
        consensus.BIP34Hash = uint256();
        consensus.BIP65Height = 76; 
        consensus.BIP66Height = 76; 
        consensus.CSVHeight = 6048; // 00000000025e930139bac5c6c31a403776da130831ab85be56578f3fa75369bb
        consensus.SegwitHeight = 6048; // 00000000002b980fcd729daaa248fd9316a5200e9b367f4ff2c42453e84201ca
        consensus.MinBIP9WarningHeight = 8064; // segwit activation height + miner confirmation window
        consensus.powLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.nPowTargetTimespan = 9 * 60;
        consensus.nPowTargetSpacing = 3 * 60;
        consensus.nDifficultyChangeActivationHeight = 90; // Activate new difficulty rules at block 90
        consensus.nOneBlockRetargetActivationHeight = 93; // Activate 1-block retarget at block 93 on testnet

        // Emergency difficulty reset parameters (shorter time for testing)
        consensus.nEmergencyDifficultyResetTime = 15 * 60; // 15 minutes for testnet
        consensus.fAllowEmergencyDifficultyReset = true;   // Enable emergency reset

        consensus.fPowAllowMinDifficultyBlocks = false;
        consensus.fPowNoRetargeting = false;
        consensus.nRuleChangeActivationThreshold = 1512; // 75% for testchains
        consensus.nMinerConfirmationWindow = 12; // nPowTargetTimespan / nPowTargetSpacing

        consensus.nPowTargetTimespanOneBlock = 3 * 60;  // 3 minutes for 1-block retarget
        consensus.nMinerConfirmationWindowOneBlock = 4; // 4 blocks confirmation window

        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;

        // Deployment of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartHeight = 2225664; // March 2022
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeoutHeight = 2435328; 

        // Deployment of MWEB (LIP-0002, LIP-0003, and LIP-0004)
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].bit = 4;
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nStartHeight = 2209536; // Jan/Feb 2022
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nTimeoutHeight = 2419200; 

        consensus.nMinimumChainWork = uint256S("0x0000000000000000000000000000000000000000000000000000000000200020");
        consensus.defaultAssumeValid = uint256S("0x150d58fcb28f605e98d9d8de663b734e24f2bdab5e0f39223010bfb583762df1"); 

        pchMessageStart[0] = 0xfd;
        pchMessageStart[1] = 0xcd;
        pchMessageStart[2] = 0x83;
        pchMessageStart[3] = 0xdc;
        nDefaultPort = 49941;
        nPruneAfterHeight = 1000;
        m_assumed_blockchain_size = 4;
        m_assumed_chain_state_size = 1;

        genesis = CreateGenesisBlock(1738496582, 745593, 0x1e0ffff0, 1, 500 * COIN);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0x150d58fcb28f605e98d9d8de663b734e24f2bdab5e0f39223010bfb583762df1"));
        assert(genesis.hashMerkleRoot == uint256S("0x3b4a2bfc695933af8c87bb1a30e0719cbb2a22cb13b74f7a624ab3eb92d2d1d2"));

        vFixedSeeds.clear();
        vSeeds.clear();
        
        vSeeds.emplace_back("testnet.aegisum.com");        

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,1);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,196);
        base58Prefixes[SCRIPT_ADDRESS2] = std::vector<unsigned char>(1,0);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,128);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x35, 0x87, 0xCF};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x35, 0x83, 0x94};

        bech32_hrp = "taegs";
        mweb_hrp = "tmweb";

        fDefaultConsistencyChecks = false;
        fRequireStandard = false;
        m_is_test_chain = true;
        m_is_mockable_chain = false;

        checkpointData = {
            {
                {0, uint256S("150d58fcb28f605e98d9d8de663b734e24f2bdab5e0f39223010bfb583762df1")},
            }
        };

        chainTxData = ChainTxData{
            // Data from RPC: getchaintxstats 4096 150d58fcb28f605e98d9d8de663b734e24f2bdab5e0f39223010bfb583762df1
            /* nTime    */ 1738496582,
            /* nTxCount */ 0,
            /* dTxRate  */ 0,
        };
    }
};

/**
 * Regression test
 */
class CRegTestParams : public CChainParams {
public:
    explicit CRegTestParams(const ArgsManager& args) {
        strNetworkID =  CBaseChainParams::REGTEST;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nSubsidyHalvingInterval = 150;
        consensus.BIP16Height = 0;
        consensus.BIP34Height = 500; // BIP34 activated on regtest (Used in functional tests)
        consensus.BIP34Hash = uint256();
        consensus.BIP65Height = 1351; // BIP65 activated on regtest (Used in functional tests)
        consensus.BIP66Height = 1251; // BIP66 activated on regtest (Used in functional tests)
        consensus.CSVHeight = 432; // CSV activated on regtest (Used in rpc activation tests)
        consensus.SegwitHeight = 0; // SEGWIT is always activated on regtest unless overridden
        consensus.MinBIP9WarningHeight = 0;
        consensus.powLimit = uint256S("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.nPowTargetTimespan = 9 * 60;
        consensus.nPowTargetSpacing = 3 * 60;
        consensus.nDifficultyChangeActivationHeight = 20000; // Activate new difficulty rules at block 20000
        consensus.nOneBlockRetargetActivationHeight = 100; // Activate 1-block retarget at block 100 on regtest

        // Emergency difficulty reset parameters (very short for testing)
        consensus.nEmergencyDifficultyResetTime = 5 * 60;  // 5 minutes for regtest
        consensus.fAllowEmergencyDifficultyReset = true;   // Enable emergency reset

        consensus.fPowAllowMinDifficultyBlocks = true;
        consensus.fPowNoRetargeting = true;
        consensus.nRuleChangeActivationThreshold = 108; // 75% for testchains
        consensus.nMinerConfirmationWindow = 144; // Faster than normal for regtest (144 instead of 2016)

        consensus.nPowTargetTimespanOneBlock = 3 * 60;  // 3 minutes for 1-block retarget  
        consensus.nMinerConfirmationWindowOneBlock = 4; // 4 blocks confirmation window

        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = 0;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;

        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::ALWAYS_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;

        // Deployment of MWEB (LIP-0002 and LIP-0003)
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].bit = 4;
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nStartTime = 1601450001; // September 30, 2020
        consensus.vDeployments[Consensus::DEPLOYMENT_MWEB].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;

        consensus.nMinimumChainWork = uint256{};
        consensus.defaultAssumeValid = uint256{};

        pchMessageStart[0] = 0xfa;
        pchMessageStart[1] = 0xbf;
        pchMessageStart[2] = 0xb5;
        pchMessageStart[3] = 0xda;
        nDefaultPort = 19444;
        nPruneAfterHeight = 1000;
        m_assumed_blockchain_size = 0;
        m_assumed_chain_state_size = 0;

        UpdateActivationParametersFromArgs(args);

        genesis = CreateGenesisBlock(1738496778, 0, 0x207fffff, 1, 500 * COIN);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0xd347ca1218939242a9e4dae9a8c1b2036384616c764a7f6aeed71e2cb98d252a"));
        assert(genesis.hashMerkleRoot == uint256S("0x3b4a2bfc695933af8c87bb1a30e0719cbb2a22cb13b74f7a624ab3eb92d2d1d2"));

        vFixedSeeds.clear(); //!< Regtest mode doesn't have any fixed seeds.
        vSeeds.clear();      //!< Regtest mode doesn't have any DNS seeds.

        fDefaultConsistencyChecks = true;
        fRequireStandard = true;
        m_is_test_chain = true;
        m_is_mockable_chain = true;

        checkpointData = {
            {
                {0, uint256S("d347ca1218939242a9e4dae9a8c1b2036384616c764a7f6aeed71e2cb98d252a")},
            }
        };

        chainTxData = ChainTxData{
            0,
            0,
            0
        };

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,1);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,196);
        base58Prefixes[SCRIPT_ADDRESS2] = std::vector<unsigned char>(1,0);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,128);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x35, 0x87, 0xCF};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x35, 0x83, 0x94};

        bech32_hrp = "raegs";
        mweb_hrp = "tmweb";
    }

    /**
     * Allows modifying the Version Bits regtest parameters.
     */
    void UpdateVersionBitsParameters(Consensus::DeploymentPos d, int64_t nStartTime, int64_t nTimeout, int64_t nStartHeight, int64_t nTimeoutHeight)
    {
        consensus.vDeployments[d].nStartTime = nStartTime;
        consensus.vDeployments[d].nTimeout = nTimeout;
        consensus.vDeployments[d].nStartHeight = nStartHeight;
        consensus.vDeployments[d].nTimeoutHeight = nTimeoutHeight;
    }
    void UpdateActivationParametersFromArgs(const ArgsManager& args);
};

void CRegTestParams::UpdateActivationParametersFromArgs(const ArgsManager& args)
{
    if (args.IsArgSet("-segwitheight")) {
        int64_t height = args.GetArg("-segwitheight", consensus.SegwitHeight);
        if (height < -1 || height >= std::numeric_limits<int>::max()) {
            throw std::runtime_error(strprintf("Activation height %ld for segwit is out of valid range. Use -1 to disable segwit.", height));
        } else if (height == -1) {
            LogPrintf("Segwit disabled for testing\n");
            height = std::numeric_limits<int>::max();
        }
        consensus.SegwitHeight = static_cast<int>(height);
    }

    if (!args.IsArgSet("-vbparams")) return;

    for (const std::string& strDeployment : args.GetArgs("-vbparams")) {
        std::vector<std::string> vDeploymentParams;
        boost::split(vDeploymentParams, strDeployment, boost::is_any_of(":"));
        if (vDeploymentParams.size() < 3 || 5 < vDeploymentParams.size()) {
            throw std::runtime_error("Version bits parameters malformed, expecting deployment:start:end[:heightstart:heightend]");
        }
        int64_t nStartTime, nTimeout, nStartHeight, nTimeoutHeight;
        if (!ParseInt64(vDeploymentParams[1], &nStartTime)) {
            throw std::runtime_error(strprintf("Invalid nStartTime (%s)", vDeploymentParams[1]));
        }
        if (!ParseInt64(vDeploymentParams[2], &nTimeout)) {
            throw std::runtime_error(strprintf("Invalid nTimeout (%s)", vDeploymentParams[2]));
        }
        if (vDeploymentParams.size() > 3 && !ParseInt64(vDeploymentParams[3], &nStartHeight)) {
            throw std::runtime_error(strprintf("Invalid nStartHeight (%s)", vDeploymentParams[3]));
        }
        if (vDeploymentParams.size() > 4 && !ParseInt64(vDeploymentParams[4], &nTimeoutHeight)) {
            throw std::runtime_error(strprintf("Invalid nTimeoutHeight (%s)", vDeploymentParams[4]));
        }
        bool found = false;
        for (int j=0; j < (int)Consensus::MAX_VERSION_BITS_DEPLOYMENTS; ++j) {
            if (vDeploymentParams[0] == VersionBitsDeploymentInfo[j].name) {
                UpdateVersionBitsParameters(Consensus::DeploymentPos(j), nStartTime, nTimeout, nStartHeight, nTimeoutHeight);
                found = true;
                LogPrintf("Setting version bits activation parameters for %s to start=%ld, timeout=%ld, start_height=%d, timeout_height=%d\n", vDeploymentParams[0], nStartTime, nTimeout, nStartHeight, nTimeoutHeight);
                break;
            }
        }
        if (!found) {
            throw std::runtime_error(strprintf("Invalid deployment (%s)", vDeploymentParams[0]));
        }
    }
}

static std::unique_ptr<const CChainParams> globalChainParams;

const CChainParams &Params() {
    assert(globalChainParams);
    return *globalChainParams;
}

std::unique_ptr<const CChainParams> CreateChainParams(const ArgsManager& args, const std::string& chain)
{
    if (chain == CBaseChainParams::MAIN) {
        return std::unique_ptr<CChainParams>(new CMainParams());
    } else if (chain == CBaseChainParams::TESTNET) {
        return std::unique_ptr<CChainParams>(new CTestNetParams());
    } else if (chain == CBaseChainParams::SIGNET) {
        return std::unique_ptr<CChainParams>(new CTestNetParams()); // TODO: Support SigNet
    } else if (chain == CBaseChainParams::REGTEST) {
        return std::unique_ptr<CChainParams>(new CRegTestParams(args));
    }
    throw std::runtime_error(strprintf("%s: Unknown chain %s.", __func__, chain));
}

void SelectParams(const std::string& network)
{
    SelectBaseParams(network);
    globalChainParams = CreateChainParams(gArgs, network);
}
