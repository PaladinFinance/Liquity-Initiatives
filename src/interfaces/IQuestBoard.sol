// SPDX-License-Identifier: None

pragma solidity 0.8.24;

interface IQuestBoard {
    enum QuestVoteType {
        NORMAL,
        BLACKLIST,
        WHITELIST
    }
    enum QuestCloseType {
        NORMAL,
        ROLLOVER,
        DISTRIBUTE
    }

    enum QuestRewardsType { FIXED, RANGE }

    /** @notice Struct with all the Quest types */
    struct QuestTypes {
        QuestVoteType voteType;
        QuestRewardsType rewardsType;
        QuestCloseType closeType;
    }

    struct Quest {
        // Address of the Quest creator (caller of createQuest() method)
        address creator;
        // Address of the ERC20 used for rewards
        address rewardToken;
        // Address of the target Gauge
        address gauge;
        // Total number of periods for the Quest
        uint48 duration;
        // Timestamp where the 1st QuestPeriod starts
        uint48 periodStart;
        // Total amount of rewards paid for this Quest
        // If changes were made to the parameters of this Quest, this will account
        // any added reward amounts
        uint256 totalRewardAmount;
        // Total reward amount that can be distributed for each period
        uint256 rewardAmountPerPeriod;
        // Min Amount of reward for each vote (for 1 veToken)
        uint256 minRewardPerVote;
        // Max Amount of reward for each vote (for 1 veToken)
        uint256 maxRewardPerVote;
        // Min Target Bias for the Gauge
        uint256 minObjectiveVotes;
        // Max Target Bias for the Gauge
        uint256 maxObjectiveVotes;
        // Quest Types
        QuestTypes types;
    }

    function createFixedQuest(
        address gauge,
        address rewardToken,
        bool startNextPeriod,
        uint48 duration,
        uint256 rewardPerVote,
        uint256 totalRewardAmount,
        uint256 feeAmount,
        QuestVoteType voteType,
        QuestCloseType closeType,
        address[] calldata voterList
    ) external returns (uint256);

    function createRangedQuest(
        address gauge,
        address rewardToken,
        bool startNextPeriod,
        uint48 duration,
        uint256 minRewardPerVote,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        uint256 feeAmount,
        QuestVoteType voteType,
        QuestCloseType closeType,
        address[] calldata voterList
    ) external returns (uint256);

    function platformFeeRatio() external view returns (uint256);
    function customPlatformFeeRatio(address) external view returns (uint256);

    function getAllPeriodsForQuestId(uint256 questID) external view returns (uint48[] memory);

    function getCurrentPeriod() external view returns (uint256);

    function questWithdrawableAmount(uint256 questID) external view returns (uint256);

    function withdrawUnusedRewards(uint256 questID, address recipient) external;
}