// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BribeInitiative } from "liquity-gov/src/BribeInitiative.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IQuestBoard } from "./interfaces/IQuestBoard.sol";

contract QuestInitiative is BribeInitiative, Ownable2Step {
    using SafeERC20 for IERC20;

    uint48 public constant DEFAULT_DURATION = 2;

    uint256 private constant BPS = 10000;

    address public questBoard;

    uint256 public pendingBudget;

    uint256 public previousQuest;

    address public targetGauge;

    struct QuestSettings {
        uint256 minRewardPerVote;
        uint256 maxRewardPerVote;
        IQuestBoard.QuestVoteType voteType;
        IQuestBoard.QuestCloseType closeType;
    }

    QuestSettings public questSettings;
    address[] public questVoterList;

    error CannotCreateQuest();

    event QuestCreated(uint256 indexed questId);
    event SettingsRewardPerVoteUpdated(uint256 newMinRewardPerVote, uint256 newMaxRewardPerVote);
    event SettingsUpdated();

    constructor(
        address _governance, address _bold, address _bribeToken, address _board, address _gauge
    ) BribeInitiative(_governance, _bold, _bribeToken) Ownable(msg.sender) {
        questBoard = _board;
        targetGauge = _gauge;
    }

    function process() external {
        _pullBudget();
        _createQuest();
    }

    function pullBudget() external {
        _pullBudget();
    }

    function _pullBudget() internal {
        uint256 amount = governance.claimForInitiative(address(this));
        pendingBudget += amount;
    }

    function _createQuest() internal {
        QuestSettings memory settings = questSettings;
        if (previousQuest != 0) {
            uint48[] memory periods = IQuestBoard(questBoard).getAllPeriodsForQuestId(previousQuest);
            uint256 lastPeriod = periods[periods.length - 1];
            // Previous Quest is not over, do not create a new one
            if (IQuestBoard(questBoard).getCurrentPeriod() <= lastPeriod) return;
        }

        uint256 feeRatio = IQuestBoard(questBoard).customPlatformFeeRatio(address(this));
        if(feeRatio == 0) feeRatio = IQuestBoard(questBoard).platformFeeRatio();
        uint256 amountOutAfterFee = (pendingBudget * BPS) / (BPS + feeRatio);
        uint256 feeAmount = (amountOutAfterFee * feeRatio) / BPS;
        pendingBudget -= (amountOutAfterFee + feeAmount);

        bold.safeIncreaseAllowance(address(_board), amountOutAfterFee + feeAmount);
        uint256 id = IQuestBoard(questBoard).createRangedQuest(
            targetGauge,
            address(bold),
            false, // Allows to create the Quest right now, and check the previous one is over before allowing to create a new one
            DEFAULT_DURATION,
            settings.minRewardPerVote,
            settings.maxRewardPerVote,
            amountOutAfterFee,
            feeAmount,
            settings.voteType,
            settings.closeType,
            questVoterList
        );
        previousQuest = id;

        emit QuestCreated(id);
    }
    
    function updateQuestSettings(
        uint256 _minRewardPerVote,
        uint256 _maxRewardPerVote,
        IQuestBoard.QuestVoteType _voteType,
        IQuestBoard.QuestCloseType _closeType,
        address[] memory _voterList
    ) external onlyOwner {
        questSettings = QuestSettings({
            minRewardPerVote: _minRewardPerVote,
            maxRewardPerVote: _maxRewardPerVote,
            voteType: _voteType,
            closeType: _closeType
        });

        delete questVoterList;
        uint256 length = _voterList.length;
        for (uint256 i = 0; i < length; i++) {
            questVoterList.push(_voterList[i]);
        }

        emit SettingsUpdated();
        emit SettingsRewardPerVoteUpdated(_minRewardPerVote, _maxRewardPerVote);
    }

    function updateQuestRewardPerVote(
        uint256 _minRewardPerVote,
        uint256 _maxRewardPerVote
    ) external onlyOwner {
        questSettings.minRewardPerVote = _minRewardPerVote;
        questSettings.maxRewardPerVote = _maxRewardPerVote;

        emit SettingsRewardPerVoteUpdated(_minRewardPerVote, _maxRewardPerVote);
    }

    function updateQuestTypeSettings(
        IQuestBoard.QuestVoteType _voteType,
        IQuestBoard.QuestCloseType _closeType,
        address[] memory _voterList
    ) external onlyOwner {
        questSettings.voteType = _voteType;
        questSettings.closeType = _closeType;

        delete questVoterList;
        uint256 length = _voterList.length;
        for (uint256 i = 0; i < length; i++) {
            questVoterList.push(_voterList[i]);
        }

        emit SettingsUpdated();
    }
 
}