// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {IGovernance} from "liquity-gov/src/interfaces/IGovernance.sol";
import {Governance} from "liquity-gov/src/Governance.sol";

import {IQuestBoard} from "../src/interfaces/IQuestBoard.sol";

import {QuestInitiative} from "../src/QuestInitiative.sol";

import {MockQuestBoard} from "./mocks/MockQuestBoard.sol";
import {MockGovernance} from "./mocks/MockGovernance.sol";

contract QuestInitiativeTest is Test {
    IERC20 private constant lqty = IERC20(address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D));
    IERC20 private constant lusd = IERC20(address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0));
    address private constant stakingV1 = address(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);
    address private constant user = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address private constant lusdHolder = address(0xcA7f01403C4989d2b1A9335A2F09dD973709957c);

    uint128 private constant REGISTRATION_FEE = 1e18;
    uint128 private constant REGISTRATION_THRESHOLD_FACTOR = 0.01e18;
    uint128 private constant UNREGISTRATION_THRESHOLD_FACTOR = 4e18;
    uint16 private constant UNREGISTRATION_AFTER_EPOCHS = 4;
    uint128 private constant VOTING_THRESHOLD_FACTOR = 0.04e18;
    uint88 private constant MIN_CLAIM = 500e18;
    uint88 private constant MIN_ACCRUAL = 1000e18;
    uint32 private constant EPOCH_DURATION = 604800;
    uint32 private constant EPOCH_VOTING_CUTOFF = 518400;

    uint48 public constant DEFAULT_DURATION = 2;

    uint256 private constant BPS = 10000;

    uint256 private constant WEEK = 604800;
    uint48 private constant WEEK_48 = 604800;

    Governance private governance;
    address[] private initialInitiatives;
    QuestInitiative private initiative;
    MockQuestBoard private questBoard;
    MockGovernance mockGovernance;
    address mockGauge = address(0x789789789);

    uint256 minRewardPerVote = 0.001e18;
    uint256 maxRewardPerVote = 0.005e18;

    uint256 newMinRewardPerVote = 0.0025e18;
    uint256 newMaxRewardPerVote = 0.0075e18;

    address otherUser = address(0x123456789);

    event QuestCreated(uint256 indexed questId);
    event SettingsRewardPerVoteUpdated(uint256 newMinRewardPerVote, uint256 newMaxRewardPerVote);
    event SettingsUpdated();

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("eth"), 20430000);

        questBoard = new MockQuestBoard();

        mockGovernance = new MockGovernance(address(lusd));

        initiative = new QuestInitiative(
            // address(vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1)),
            address(mockGovernance),
            address(lusd),
            address(lqty),
            address(questBoard),
            address(mockGauge)
        );

        initialInitiatives.push(address(initiative));

        IGovernance.Configuration memory config = IGovernance.Configuration({
            registrationFee: REGISTRATION_FEE,
            registrationThresholdFactor: REGISTRATION_THRESHOLD_FACTOR,
            unregistrationThresholdFactor: UNREGISTRATION_THRESHOLD_FACTOR,
            unregistrationAfterEpochs: UNREGISTRATION_AFTER_EPOCHS,
            votingThresholdFactor: VOTING_THRESHOLD_FACTOR,
            minClaim: MIN_CLAIM,
            minAccrual: MIN_ACCRUAL,
            epochStart: uint32(block.timestamp),
            epochDuration: EPOCH_DURATION,
            epochVotingCutoff: EPOCH_VOTING_CUTOFF
        });

        governance = new Governance(
            address(lqty), address(lusd), stakingV1, address(lusd), config, address(this), initialInitiatives
        );

        vm.startPrank(lusdHolder);
        lusd.transfer(address(this), 3000e18);
        vm.stopPrank();
    }

    function test_correctInit() public {
        assertEq(initiative.questBoard(), address(questBoard));
        assertEq(initiative.targetGauge(), address(mockGauge));
        assertEq(initiative.pendingBudget(), 0);
    }

    function test_updateQuestSettings() public {
        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        vm.expectEmit(true, true, true, true);
        emit SettingsUpdated();
        vm.expectEmit(true, true, true, true);
        emit SettingsRewardPerVoteUpdated(minRewardPerVote, maxRewardPerVote);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        assertEq(settings.minRewardPerVote, minRewardPerVote);
        assertEq(settings.maxRewardPerVote, maxRewardPerVote);
        assertEq(uint256(settings.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(settings.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(initiative.questVoterList(0), address(0x11111));
        assertEq(initiative.questVoterList(1), address(0x22222));
    }

    function test_updateQuestSettings_subsequent() public {
        address[] memory voterList = new address[](2);
        address[] memory voterList2 = new address[](1);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);
        voterList2[0] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.expectEmit(true, true, true, true);
        emit SettingsUpdated();
        vm.expectEmit(true, true, true, true);
        emit SettingsRewardPerVoteUpdated(newMinRewardPerVote, newMaxRewardPerVote);

        initiative.updateQuestSettings(
            newMinRewardPerVote,
            newMaxRewardPerVote,
            IQuestBoard.QuestVoteType.WHITELIST,
            IQuestBoard.QuestCloseType.ROLLOVER,
            voterList2
        );

        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        assertEq(settings.minRewardPerVote, newMinRewardPerVote);
        assertEq(settings.maxRewardPerVote, newMaxRewardPerVote);
        assertEq(uint256(settings.voteType), uint256(IQuestBoard.QuestVoteType.WHITELIST));
        assertEq(uint256(settings.closeType), uint256(IQuestBoard.QuestCloseType.ROLLOVER));

        assertEq(initiative.questVoterList(0), address(0x22222));
    }

    function test_updateQuestSettings_failOnlyOwner() public {
        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        vm.startPrank(otherUser);

        vm.expectRevert();
        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.stopPrank();
    }

    function test_updateQuestRewardPerVote() public {
        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.expectEmit(true, true, true, true);
        emit SettingsRewardPerVoteUpdated(newMinRewardPerVote, newMaxRewardPerVote);

        initiative.updateQuestRewardPerVote(
            newMinRewardPerVote,
            newMaxRewardPerVote
        );

        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        assertEq(settings.minRewardPerVote, newMinRewardPerVote);
        assertEq(settings.maxRewardPerVote, newMaxRewardPerVote);
        assertEq(uint256(settings.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(settings.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(initiative.questVoterList(0), address(0x11111));
        assertEq(initiative.questVoterList(1), address(0x22222));
    }

    function test_updateQuestRewardPerVote_failOnlyOwner() public {
        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.startPrank(otherUser);

        vm.expectRevert();
        initiative.updateQuestRewardPerVote(newMinRewardPerVote, newMaxRewardPerVote);

        vm.stopPrank();
    }

    function test_updateQuestTypeSettings() public {
        address[] memory voterList = new address[](2);
        address[] memory voterList2 = new address[](1);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);
        voterList2[0] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.expectEmit(true, true, true, true);
        emit SettingsUpdated();

        initiative.updateQuestTypeSettings(
            IQuestBoard.QuestVoteType.WHITELIST,
            IQuestBoard.QuestCloseType.ROLLOVER,
            voterList2
        );

        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        assertEq(settings.minRewardPerVote, minRewardPerVote);
        assertEq(settings.maxRewardPerVote, maxRewardPerVote);
        assertEq(uint256(settings.voteType), uint256(IQuestBoard.QuestVoteType.WHITELIST));
        assertEq(uint256(settings.closeType), uint256(IQuestBoard.QuestCloseType.ROLLOVER));

        assertEq(initiative.questVoterList(0), address(0x22222));
    }

    function test_updateQuestTypeSettings_failOnlyOwner() public {
        address[] memory voterList = new address[](2);
        address[] memory voterList2 = new address[](1);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);
        voterList2[0] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        vm.startPrank(otherUser);

        vm.expectRevert();
        initiative.updateQuestTypeSettings(
            IQuestBoard.QuestVoteType.WHITELIST,
            IQuestBoard.QuestCloseType.ROLLOVER,
            voterList2
        );

        vm.stopPrank();
    }

    function test_pullBudget(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 oldPendingBudget = initiative.pendingBudget();

        initiative.pullBudget();

        assertEq(initiative.pendingBudget(), oldPendingBudget + amount);
    }

    function test_pullBudget_subsequent(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);

        deal(address(lusd), address(mockGovernance), 1500e18);
        initiative.pullBudget();

        skip(3 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 oldPendingBudget = initiative.pendingBudget();

        initiative.pullBudget();

        assertEq(initiative.pendingBudget(), oldPendingBudget + amount);
    }

    function test_pullBudget_zeroAmount() public {
        deal(address(lusd), address(mockGovernance), 1500e18);
        initiative.pullBudget();

        skip(3 days);

        uint256 oldPendingBudget = initiative.pendingBudget();

        initiative.pullBudget();

        assertEq(initiative.pendingBudget(), oldPendingBudget);
    }

    function test_process(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);

        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();
        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        uint256 feeRatio = questBoard.customPlatformFeeRatio(address(initiative));
        if(feeRatio == 0) feeRatio = questBoard.platformFeeRatio();
        uint256 amountOutAfterFee = (_budget * BPS) / (BPS + feeRatio);
        uint256 feeAmount = (amountOutAfterFee * feeRatio) / BPS;
        _budget -= (amountOutAfterFee + feeAmount);

        uint256 expectedId = questBoard.startId();
        uint256 currentPeriod = questBoard.getCurrentPeriod();


        vm.expectEmit(true, true, true, true);
        emit QuestCreated(expectedId);

        initiative.process();

        assertEq(initiative.previousQuest(), expectedId);

        assertEq(initiative.pendingBudget(), _budget);

        IQuestBoard.Quest memory questData = questBoard.quests(expectedId);
        assertEq(questData.creator, address(initiative));
        assertEq(questData.rewardToken, address(lusd));
        assertEq(questData.gauge, address(mockGauge));
        assertEq(questData.duration, DEFAULT_DURATION);
        assertEq(questData.periodStart, currentPeriod);
        assertEq(questData.totalRewardAmount, amountOutAfterFee);
        assertEq(questData.rewardAmountPerPeriod, amountOutAfterFee / DEFAULT_DURATION);
        assertEq(questData.minRewardPerVote, settings.minRewardPerVote);
        assertEq(questData.maxRewardPerVote, settings.maxRewardPerVote);

        assertEq(uint256(questData.types.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(questData.types.rewardsType), uint256(IQuestBoard.QuestRewardsType.RANGE));
        assertEq(uint256(questData.types.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(questBoard._questVoterList(expectedId, 0), address(0x11111));
        assertEq(questBoard._questVoterList(expectedId, 1), address(0x22222));

        assertEq(questBoard._questPeriods(expectedId, 0), uint48(currentPeriod));
        assertEq(questBoard._questPeriods(expectedId, 1), uint48(currentPeriod) + WEEK_48);

        assertEq(questBoard.startId(), expectedId + 1);

    }

    function test_process_budgetAlreadyPulled(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);

        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        deal(address(lusd), address(mockGovernance), amount);
        initiative.pullBudget();

        uint256 _budget = initiative.pendingBudget();
        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        uint256 feeRatio = questBoard.customPlatformFeeRatio(address(initiative));
        if(feeRatio == 0) feeRatio = questBoard.platformFeeRatio();
        uint256 amountOutAfterFee = (_budget * BPS) / (BPS + feeRatio);
        uint256 feeAmount = (amountOutAfterFee * feeRatio) / BPS;
        _budget -= (amountOutAfterFee + feeAmount);

        uint256 expectedId = questBoard.startId();
        uint256 currentPeriod = questBoard.getCurrentPeriod();


        vm.expectEmit(true, true, true, true);
        emit QuestCreated(expectedId);

        initiative.process();

        assertEq(initiative.previousQuest(), expectedId);

        assertEq(initiative.pendingBudget(), _budget);

        IQuestBoard.Quest memory questData = questBoard.quests(expectedId);
        assertEq(questData.creator, address(initiative));
        assertEq(questData.rewardToken, address(lusd));
        assertEq(questData.gauge, address(mockGauge));
        assertEq(questData.duration, DEFAULT_DURATION);
        assertEq(questData.periodStart, currentPeriod);
        assertEq(questData.totalRewardAmount, amountOutAfterFee);
        assertEq(questData.rewardAmountPerPeriod, amountOutAfterFee / DEFAULT_DURATION);
        assertEq(questData.minRewardPerVote, settings.minRewardPerVote);
        assertEq(questData.maxRewardPerVote, settings.maxRewardPerVote);

        assertEq(uint256(questData.types.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(questData.types.rewardsType), uint256(IQuestBoard.QuestRewardsType.RANGE));
        assertEq(uint256(questData.types.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(questBoard._questVoterList(expectedId, 0), address(0x11111));
        assertEq(questBoard._questVoterList(expectedId, 1), address(0x22222));

        assertEq(questBoard._questPeriods(expectedId, 0), uint48(currentPeriod));
        assertEq(questBoard._questPeriods(expectedId, 1), uint48(currentPeriod) + WEEK_48);

        assertEq(questBoard.startId(), expectedId + 1);

    }

    function test_process_afterPreviousQuest(uint256 amount) public {
        vm.assume(amount <= 99999 ether);

        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        deal(address(lusd), address(mockGovernance), 1500e18);

        initiative.process();

        skip(15 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 leftovers = questBoard.questWithdrawableAmount(initiative.previousQuest());

        uint256 _budget = amount + initiative.pendingBudget() + leftovers;
        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        uint256 feeRatio = questBoard.customPlatformFeeRatio(address(initiative));
        if(feeRatio == 0) feeRatio = questBoard.platformFeeRatio();
        uint256 amountOutAfterFee = (_budget * BPS) / (BPS + feeRatio);
        uint256 feeAmount = (amountOutAfterFee * feeRatio) / BPS;
        _budget -= (amountOutAfterFee + feeAmount);

        uint256 expectedId = questBoard.startId();
        uint256 currentPeriod = questBoard.getCurrentPeriod();


        vm.expectEmit(true, true, true, true);
        emit QuestCreated(expectedId);

        initiative.process();

        assertEq(initiative.previousQuest(), expectedId);

        assertEq(initiative.pendingBudget(), _budget);

        IQuestBoard.Quest memory questData = questBoard.quests(expectedId);
        assertEq(questData.creator, address(initiative));
        assertEq(questData.rewardToken, address(lusd));
        assertEq(questData.gauge, address(mockGauge));
        assertEq(questData.duration, DEFAULT_DURATION);
        assertEq(questData.periodStart, currentPeriod);
        assertEq(questData.totalRewardAmount, amountOutAfterFee);
        assertEq(questData.rewardAmountPerPeriod, amountOutAfterFee / DEFAULT_DURATION);
        assertEq(questData.minRewardPerVote, settings.minRewardPerVote);
        assertEq(questData.maxRewardPerVote, settings.maxRewardPerVote);

        assertEq(uint256(questData.types.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(questData.types.rewardsType), uint256(IQuestBoard.QuestRewardsType.RANGE));
        assertEq(uint256(questData.types.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(questBoard._questVoterList(expectedId, 0), address(0x11111));
        assertEq(questBoard._questVoterList(expectedId, 1), address(0x22222));

        assertEq(questBoard._questPeriods(expectedId, 0), uint48(currentPeriod));
        assertEq(questBoard._questPeriods(expectedId, 1), uint48(currentPeriod) + WEEK_48);

        assertEq(questBoard.startId(), expectedId + 1);

    }

    function test_process_whileQuestActiveDoNothing(uint256 amount) public {
        vm.assume(amount <= 99999 ether);

        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        deal(address(lusd), address(mockGovernance), 1500e18);

        initiative.process();

        skip(8 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 prevBudget = initiative.pendingBudget();
        uint256 prevQuest = initiative.previousQuest();
        uint256 boardNextId = questBoard.startId();

        initiative.process();

        assertEq(initiative.previousQuest(), prevQuest);
        assertEq(initiative.pendingBudget(), prevBudget + amount);

        assertEq(questBoard.startId(), boardNextId);

    }

    function test_process_customFees(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);

        questBoard.setCustomeFeeRatio(address(initiative), 200);

        address[] memory voterList = new address[](2);
        voterList[0] = address(0x11111);
        voterList[1] = address(0x22222);

        initiative.updateQuestSettings(
            minRewardPerVote,
            maxRewardPerVote,
            IQuestBoard.QuestVoteType.BLACKLIST,
            IQuestBoard.QuestCloseType.NORMAL,
            voterList
        );

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();
        QuestInitiative.QuestSettings memory settings = initiative.questSettings();
        uint256 feeRatio = questBoard.customPlatformFeeRatio(address(initiative));
        if(feeRatio == 0) feeRatio = questBoard.platformFeeRatio();
        uint256 amountOutAfterFee = (_budget * BPS) / (BPS + feeRatio);
        uint256 feeAmount = (amountOutAfterFee * feeRatio) / BPS;
        _budget -= (amountOutAfterFee + feeAmount);

        uint256 expectedId = questBoard.startId();
        uint256 currentPeriod = questBoard.getCurrentPeriod();


        vm.expectEmit(true, true, true, true);
        emit QuestCreated(expectedId);

        initiative.process();

        assertEq(initiative.previousQuest(), expectedId);

        assertEq(initiative.pendingBudget(), _budget);

        IQuestBoard.Quest memory questData = questBoard.quests(expectedId);
        assertEq(questData.creator, address(initiative));
        assertEq(questData.rewardToken, address(lusd));
        assertEq(questData.gauge, address(mockGauge));
        assertEq(questData.duration, DEFAULT_DURATION);
        assertEq(questData.periodStart, currentPeriod);
        assertEq(questData.totalRewardAmount, amountOutAfterFee);
        assertEq(questData.rewardAmountPerPeriod, amountOutAfterFee / DEFAULT_DURATION);
        assertEq(questData.minRewardPerVote, settings.minRewardPerVote);
        assertEq(questData.maxRewardPerVote, settings.maxRewardPerVote);

        assertEq(uint256(questData.types.voteType), uint256(IQuestBoard.QuestVoteType.BLACKLIST));
        assertEq(uint256(questData.types.rewardsType), uint256(IQuestBoard.QuestRewardsType.RANGE));
        assertEq(uint256(questData.types.closeType), uint256(IQuestBoard.QuestCloseType.NORMAL));

        assertEq(questBoard._questVoterList(expectedId, 0), address(0x11111));
        assertEq(questBoard._questVoterList(expectedId, 1), address(0x22222));

        assertEq(questBoard._questPeriods(expectedId, 0), uint48(currentPeriod));
        assertEq(questBoard._questPeriods(expectedId, 1), uint48(currentPeriod) + WEEK_48);

        assertEq(questBoard.startId(), expectedId + 1);

    }

}