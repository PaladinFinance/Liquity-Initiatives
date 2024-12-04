// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BribeInitiative } from "liquity-gov/src/BribeInitiative.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IValkyrieBasicIncentive, IncentivizedPoolId } from "./interfaces/IValkyrieBasicIncentive.sol";

contract ValkyrieInitiative is BribeInitiative, Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 public constant DEFAULT_DURATION = 2 weeks;

    uint256 private constant MAX_BPS = 10000;

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
        pendingBudget = 0;
        uint256 duration = DEFAULT_DURATION;

        IValkyrieBasicIncentive.RewardData memory currentDistribution = IValkyrieBasicIncentive(valkyrieIncentives).poolRewardData(
            targetPoolId,
            address(bold)
        );

        if(currentDistribution.endTimestamp > block.timestamp) {
            uint256 remainingDuration;
            uint256 remainingBudget;
            uint256 feeRatio = IValkyrieBasicIncentive(valkyrieIncentives).getFeeRatio(address(this));

            remainingDuration = currentDistribution.endTimestamp - block.timestamp;
            remainingBudget = currentDistribution.ratePerSec * remainingDuration;

            duration = DEFAULT_DURATION - remainingDuration;

            uint256 newDepositedBudget = newBudget - ((feeRatio * newBudget) / MAX_BPS);
            uint256 newRate = (newDepositedBudget + remainingBudget) / (DEFAULT_DURATION);

            // Valkyrie will not permit to reduce the ratePerSec of the distribution, so if the new one is lower,
            // we will not deposit the rewards until having enough budget to keep or increase the ratePerSec
            if(newRate < currentDistribution.ratePerSec) return;
        }
        
        bold.safeIncreaseAllowance(address(valkyrieIncentives), newBudget);
        IValkyrieBasicIncentive(valkyrieIncentives).depositRewards(
            targetPoolId,
            address(bold),
            newBudget,
            duration
        );
    }

}