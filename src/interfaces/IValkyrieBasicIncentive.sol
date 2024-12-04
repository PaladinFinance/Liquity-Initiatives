// SPDX-License-Identifier: None

pragma solidity 0.8.24;

import { PoolId } from "uniswap/v4-core/src/types/PoolId.sol";

type IncentivizedPoolId is bytes32;

/// @notice Returns the key for identifying a pool that can be incentivized
struct IncentivizedPoolKey {
    /// @notice Id of the Uni V4 Pool
    PoolId id;
    /// @notice Address of the LP token associted with in the Hook (if no LP token, address 0x0)
    address lpToken;
}

/// @notice Library for computing the ID of a pool that can be incentivized
library IncentivizedPoolIdLibrary {
    /// @notice Returns value equal to keccak256(abi.encode(IncentivizedPoolKey))
    function toId(IncentivizedPoolKey memory key) internal pure returns (IncentivizedPoolId) {
        return IncentivizedPoolId.wrap(keccak256(abi.encode(key)));
    }
}

interface IValkyrieBasicIncentive {

    struct RewardData {
        /// @notice Timestamp at which the distribution ends
        uint32 endTimestamp;
        /// @notice Timestamp at which the last update was made
        uint32 lastUpdateTime;
        /// @notice Current rate per second for the distribution
        uint96 ratePerSec;
        /// @notice Last updated reward per token
        uint96 rewardPerTokenStored;
    }

    function depositRewards(
        IncentivizedPoolId id,
        address token,
        uint256 amount,
        uint256 duration
    ) external;

    function poolRewardData(IncentivizedPoolId id, address token) external view returns (RewardData memory);

    function getFeeRatio(address account) external view returns (uint256);
}