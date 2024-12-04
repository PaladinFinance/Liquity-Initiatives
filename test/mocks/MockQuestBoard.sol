// SPDX-License-Identifier: None

pragma solidity 0.8.24;

import { IQuestBoard } from "../../src/interfaces/IQuestBoard.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockQuestBoard is IQuestBoard {
    using SafeERC20 for IERC20;

    uint256 private constant WEEK = 604800;
    uint48 private constant WEEK_48 = 604800;

    uint256 startId = 1;

    mapping(uint256 => Quest) public _quests;
    mapping(uint256 => uint48[]) public _questPeriods;
    mapping(uint256 => address[]) public _questVoterList;

    mapping(address => uint256) public _customeFeeRatios;

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
    ) external returns (uint256) {
        uint256 questID = startId++;

        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewardAmount + feeAmount);

        uint48 startPeriod = safe48(getCurrentPeriod());
        startPeriod = startNextPeriod ? startPeriod + WEEK_48 : startPeriod;

        _quests[questID] = Quest({
            creator: msg.sender,
            rewardToken: rewardToken,
            gauge: gauge,
            duration: duration,
            periodStart: startPeriod,
            totalRewardAmount: totalRewardAmount,
            rewardAmountPerPeriod: rewardPerVote,
            minRewardPerVote: rewardPerVote,
            maxRewardPerVote: rewardPerVote,
            minObjectiveVotes: 0,
            maxObjectiveVotes: 0,
            types: QuestTypes({
                voteType: voteType,
                rewardsType: QuestRewardsType.FIXED,
                closeType: closeType
            })
        });
        
        for(uint256 i = 0; i < voterList.length; i++) {
            _questVoterList[questID].push(voterList[i]);
        }
        
        for(uint48 i = 0; i < duration; i++) {
            _questPeriods[questID].push(startPeriod + (i * WEEK_48));
        }

        return questID;
    }

    struct Vars {
        uint256 questID;
        uint48 startPeriod;
    }

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
    ) external returns (uint256) {
        // Set the Quest Types for the new Quest
        QuestTypes memory types = QuestTypes({
            voteType: voteType,
            rewardsType: QuestRewardsType.RANGE,
            closeType: closeType
        });

        return _createRangedQuest(
            gauge,
            rewardToken,
            types,
            startNextPeriod,
            duration,
            minRewardPerVote,
            maxRewardPerVote,
            totalRewardAmount,
            feeAmount,
            voterList
        );
    }

    function _createRangedQuest(
        address gauge,
        address rewardToken,
        QuestTypes memory types,
        bool startNextPeriod,
        uint48 duration,
        uint256 minRewardPerVote,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        uint256 feeAmount,
        address[] calldata voterList
    ) internal returns (uint256) {
        Vars memory vars;
        vars.questID = startId++;

        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewardAmount + feeAmount);

        vars.startPeriod = safe48(getCurrentPeriod());
        vars.startPeriod = startNextPeriod ? vars.startPeriod + WEEK_48 : vars.startPeriod;

        _quests[vars.questID] = Quest({
            creator: msg.sender,
            rewardToken: rewardToken,
            gauge: gauge,
            duration: duration,
            periodStart: vars.startPeriod,
            totalRewardAmount: totalRewardAmount,
            rewardAmountPerPeriod: minRewardPerVote,
            minRewardPerVote: minRewardPerVote,
            maxRewardPerVote: maxRewardPerVote,
            minObjectiveVotes: 0,
            maxObjectiveVotes: 0,
            types: types
        });
        
        for(uint256 i; i < voterList.length; i++) {
            _questVoterList[vars.questID].push(voterList[i]);
        }
        
        for(uint48 i = 0; i < duration; i++) {
            _questPeriods[vars.questID].push(vars.startPeriod + (i * WEEK_48));
        }

        return vars.questID;
    }

    function platformFeeRatio() external view returns (uint256) {
        return 400;
    }

    function customPlatformFeeRatio(address user) external view returns (uint256) {
        return _customeFeeRatios[user];
    }

    function setCustomeFeeRatio(address user, uint256 ratio) external {
        _customeFeeRatios[user] = ratio;
    }

    function getAllPeriodsForQuestId(uint256 questID) external view returns (uint48[] memory) {
        return _questPeriods[questID];
    }

    function getCurrentPeriod() public view returns(uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }

    function safe48(uint n) internal pure returns (uint48) {
        return uint48(n);
    }
}