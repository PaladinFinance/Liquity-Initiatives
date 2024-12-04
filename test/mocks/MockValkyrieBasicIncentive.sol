// SPDX-License-Identifier: None

pragma solidity 0.8.24;

import { IValkyrieBasicIncentive, IncentivizedPoolId } from "../../src/interfaces/IValkyrieBasicIncentive.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

contract MockValkyrieBasicIncentive is IValkyrieBasicIncentive {
    using SafeERC20 for IERC20;
    using SafeCast for *;

    uint256 private constant MAX_BPS = 10000;

    mapping(IncentivizedPoolId => mapping(address => RewardData)) public _poolRewardData;
    mapping(IncentivizedPoolId => address[]) public poolRewards;
    mapping(address => uint256) public accumulatedFees;
    mapping(address => uint256) public _feeRatios;
    uint256 public defaultFee = 100; //bps

    error CannotReduceRate();

    function _getFeeRatio(address account) internal view virtual returns (uint256) {
        return _feeRatios[account] > 0 ? _feeRatios[account] : defaultFee;
    }

    function depositRewards(
        IncentivizedPoolId id,
        address token,
        uint256 amount,
        uint256 duration
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 feeAmount = (_getFeeRatio(msg.sender) * amount) / MAX_BPS;
        accumulatedFees[token] += feeAmount;
        amount -= feeAmount;

        RewardData storage _state = _poolRewardData[id][token];

        if (_state.endTimestamp < block.timestamp) {
            if (_state.endTimestamp == 0) poolRewards[id].push(token);

            // Calculate the rate
            uint256 rate = amount / duration;

            // Store the new reward distribution parameters
            _state.ratePerSec = rate.toUint96();
            _state.endTimestamp = (block.timestamp + duration).toUint32();
            _state.lastUpdateTime = (block.timestamp).toUint32();
        } else {
            // Calculates the remianing duration left for the current distribution
            uint256 remainingDuration = _state.endTimestamp - block.timestamp;
            // And calculates the new duration
            uint256 newDuration = remainingDuration + duration;

            // Calculates the leftover rewards from the current distribution
            uint256 leftoverRewards = _state.ratePerSec * remainingDuration;

            // Calculates the new rate
            uint256 newRate = (amount + leftoverRewards) / newDuration;
            if (newRate < _state.ratePerSec) revert CannotReduceRate();

            // Stores the new reward distribution parameters
            _state.ratePerSec = newRate.toUint96();
            _state.endTimestamp = (block.timestamp + newDuration).toUint32();
            _state.lastUpdateTime = (block.timestamp).toUint32();
        }
    }

    function poolRewardData(IncentivizedPoolId id, address token) external view returns (RewardData memory) {
        return _poolRewardData[id][token];
    }

    function getFeeRatio(address account) external view virtual returns (uint256) {
        return _getFeeRatio(account);
    }

    function setFeeRatio(address account, uint256 ratio) external {
        _feeRatios[account] = ratio;
    }

}