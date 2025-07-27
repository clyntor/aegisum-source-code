// Copyright (c) 2009-2010 Satoshi Nakamoto
// Copyright (c) 2009-2018 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <pow.h>

#include <arith_uint256.h>
#include <chain.h>
#include <primitives/block.h>
#include <uint256.h>

unsigned int GetNextWorkRequired(const CBlockIndex* pindexLast, const CBlockHeader *pblock, const Consensus::Params& params)
{
    assert(pindexLast != nullptr);
    unsigned int nProofOfWorkLimit = UintToArith256(params.powLimit).GetCompact();

    // Check if we're using 1-block retarget (after block 46000)
    bool fOneBlockRetarget = (pindexLast->nHeight + 1) >= params.nOneBlockRetargetActivationHeight;
    
    if (fOneBlockRetarget) {
        // 1-block retarget: adjust difficulty every block
        if (pindexLast->pprev == nullptr) {
            // Genesis block case
            return nProofOfWorkLimit;
        }
        
        // For 1-block retarget, use the previous block as the reference
        return CalculateNextWorkRequired(pindexLast, pindexLast->pprev->GetBlockTime(), params);
    }

    // Original logic for blocks before 1-block retarget activation
    // Only change once per difficulty adjustment interval
    // Get the correct difficulty adjustment interval for this height
    int64_t nDifficultyAdjustmentInterval = params.GetDifficultyAdjustmentInterval(pindexLast->nHeight + 1);

    // Only change once per difficulty adjustment interval
    if ((pindexLast->nHeight+1) % nDifficultyAdjustmentInterval != 0)
    {
        if (params.fPowAllowMinDifficultyBlocks)
        {
            // Special difficulty rule for testnet:
            // If the new block's timestamp is more than 2* 10 minutes
            // then allow mining of a min-difficulty block.
            if (pblock->GetBlockTime() > pindexLast->GetBlockTime() + params.nPowTargetSpacing*2)
                return nProofOfWorkLimit;
            else
            {
                // Return the last non-special-min-difficulty-rules-block
                const CBlockIndex* pindex = pindexLast;
                while (pindex->pprev && pindex->nHeight % nDifficultyAdjustmentInterval != 0 && pindex->nBits == nProofOfWorkLimit)
                    pindex = pindex->pprev;
                return pindex->nBits;
            }
        }
        return pindexLast->nBits;
    }

    // Go back by what we want to be 14 days worth of blocks
    // Aegisum: This fixes an issue where a 51% attack can change difficulty at will.
    // Go back the full period unless it's the first retarget after genesis. Code courtesy of Art Forz
    int blockstogoback = nDifficultyAdjustmentInterval-1;
    if ((pindexLast->nHeight+1) != nDifficultyAdjustmentInterval)
        blockstogoback = nDifficultyAdjustmentInterval;

    // Go back by what we want to be 14 days worth of blocks
    const CBlockIndex* pindexFirst = pindexLast;
    for (int i = 0; pindexFirst && i < blockstogoback; i++)
        pindexFirst = pindexFirst->pprev;

    assert(pindexFirst);

    return CalculateNextWorkRequired(pindexLast, pindexFirst->GetBlockTime(), params);
}

unsigned int CalculateNextWorkRequired(const CBlockIndex* pindexLast, int64_t nFirstBlockTime, const Consensus::Params& params)
{
    if (params.fPowNoRetargeting)
        return pindexLast->nBits;

    // Limit adjustment step
    int64_t nActualTimespan = pindexLast->GetBlockTime() - nFirstBlockTime;
    
    // Determine which rules to use based on block height
    bool fOneBlockRetarget = (pindexLast->nHeight + 1) >= params.nOneBlockRetargetActivationHeight;
    bool fNewRules = pindexLast->nHeight >= params.nDifficultyChangeActivationHeight;
    
    // Get the correct target timespan for this height
    int64_t nTargetTimespan = params.GetPowTargetTimespan(pindexLast->nHeight + 1);
    
    if (fOneBlockRetarget) {
        // 1-block retarget: 50% max difficulty increase, 6x max difficulty decrease
        if (nActualTimespan < (nTargetTimespan * 2) / 3)
            nActualTimespan = (nTargetTimespan * 2) / 3;  // 50% difficulty increase (1.5x harder)
        if (nActualTimespan > nTargetTimespan * 6)
            nActualTimespan = nTargetTimespan * 6;  // 6x difficulty decrease (6x easier)
    } else {
        // Use the fNewRules logic for difficulty swing percentages (block 21000+)
        if (fNewRules) {
            // New rules (block 21000+): limit upward difficulty change to 1.5x (instead of 4x)
            if (nActualTimespan < (nTargetTimespan * 2) / 3)
                nActualTimespan = (nTargetTimespan * 2) / 3;
                
            // New rules: allow downward difficulty change up to 6x (instead of 4x)
            if (nActualTimespan > nTargetTimespan * 6)
                nActualTimespan = nTargetTimespan * 6;
        } else {
            // Old rules (blocks 0-20999): limit upward difficulty change to 4x
            if (nActualTimespan < nTargetTimespan/4)
                nActualTimespan = nTargetTimespan/4;
                
            // Old rules: limit downward difficulty change to 4x
            if (nActualTimespan > nTargetTimespan*4)
                nActualTimespan = nTargetTimespan*4;
        }
    }

    // Retarget
    arith_uint256 bnNew;
    arith_uint256 bnOld;
    bnNew.SetCompact(pindexLast->nBits);
    bnOld = bnNew;
    // Aegisum: intermediate uint256 can overflow by 1 bit
    const arith_uint256 bnPowLimit = UintToArith256(params.powLimit);
    bool fShift = bnNew.bits() > bnPowLimit.bits() - 1;
    if (fShift)
        bnNew >>= 1;
    bnNew *= nActualTimespan;
    bnNew /= nTargetTimespan;
    if (fShift)
        bnNew <<= 1;

    if (bnNew > bnPowLimit)
        bnNew = bnPowLimit;

    return bnNew.GetCompact();
}

bool CheckProofOfWork(uint256 hash, unsigned int nBits, const Consensus::Params& params)
{
    bool fNegative;
    bool fOverflow;
    arith_uint256 bnTarget;

    bnTarget.SetCompact(nBits, &fNegative, &fOverflow);

    // Check range
    if (fNegative || bnTarget == 0 || fOverflow || bnTarget > UintToArith256(params.powLimit))
        return false;

    // Check proof of work matches claimed amount
    if (UintToArith256(hash) > bnTarget)
        return false;

    return true;
}
