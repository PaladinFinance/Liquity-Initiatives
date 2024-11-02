// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BribeInitiative } from "liquity-gov/src/BribeInitiative.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { IValkyrieBasicIncentive, IncentivizedPoolId } from "./interfaces/IValkyrieBasicIncentive.sol";

contract ValkyrieInitiative is BribeInitiative, Ownable2Step {

    uint256 public constant DEFAULT_DURATION = 2 weeks;

    uint256 public distributionRatioThreshold = 0.91e18;

    address public valkyrieIncentives;

    IncentivizedPoolId public targetPoolId;

    uint256 public pendingBudget;

    event IncentiveDepsoited();

    constructor(
        address _governance, address _bold, address _bribeToken, address _valkyrieIncentives, IncentivizedPoolId _poolId
    ) BribeInitiative(_governance, _bold, _bribeToken) Ownable(msg.sender) {
        valkyrieIncentives = _valkyrieIncentives;
        targetPoolId = _poolId;

        bold.approve(address(_valkyrieIncentives), type(uint256).max);
    }

    function process() external {
        _pullBudget();
        _depositIncentive();
    }

    function pullBudget() external {
        _pullBudget();
    }

    function _pullBudget() internal {
        uint256 amount = governance.claimForInitiative(address(this));
        pendingBudget += amount;
    }

    function _depositIncentive() internal {
        uint256 newBudget = pendingBudget;
        IValkyrieBasicIncentive.RewardData memory currentDistribution = IValkyrieBasicIncentive(valkyrieIncentives).poolRewardData(
            targetPoolId,
            address(bold)
        );

        uint256 remainingDuration;
        uint256 remainingBudget;
        if(currentDistribution.endTimestamp > block.timestamp) {
            remainingDuration = currentDistribution.endTimestamp - block.timestamp;
            remainingBudget = currentDistribution.ratePerSec * remainingDuration;
        }

        uint256 newRate = (newBudget + remainingBudget) / (DEFAULT_DURATION + remainingDuration);

        // Valkyrie will not permit to reduce the ratePerSec of the distribution, so if the new one is lower,
        // we will not deposit the rewards until having enough budget to keep or increase the ratePerSec
        if(newRate < currentDistribution.ratePerSec) return;

        IValkyrieBasicIncentive(valkyrieIncentives).depositRewards(
            targetPoolId,
            address(bold),
            newBudget,
            DEFAULT_DURATION
        );
    }

}