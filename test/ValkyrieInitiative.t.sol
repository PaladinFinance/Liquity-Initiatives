// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {IGovernance} from "liquity-gov/src/interfaces/IGovernance.sol";
import {Governance} from "liquity-gov/src/Governance.sol";

import {ValkyrieInitiative} from "../src/ValkyrieInitiative.sol";

import {MockValkyrieBasicIncentive} from "./mocks/MockValkyrieBasicIncentive.sol";
import {MockGovernance} from "./mocks/MockGovernance.sol";

import { IValkyrieBasicIncentive, IncentivizedPoolId } from "../src/interfaces/IValkyrieBasicIncentive.sol";

contract ValkyrieInitiativeTest is Test {
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

    uint256 public constant DEFAULT_DURATION = 2 weeks;

    uint256 private constant MAX_BPS = 10000;

    uint256 public distributionRatioThreshold = 0.91e18;

    Governance private governance;
    address[] private initialInitiatives;
    ValkyrieInitiative private initiative;
    MockValkyrieBasicIncentive private valkyrie;
    MockGovernance mockGovernance;

    address otherUser = address(0x123456789);

    IncentivizedPoolId poolId;
    bytes32 poolIdBytes = hex"123456789876543210";

    event IncentiveDeposited();

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("eth"), 20430000);

        poolId = IncentivizedPoolId.wrap(poolIdBytes);

        valkyrie = new MockValkyrieBasicIncentive();

        mockGovernance = new MockGovernance(address(lusd));

        initiative = new ValkyrieInitiative(
            // address(vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1)),
            address(mockGovernance),
            address(lusd),
            address(lqty),
            address(valkyrie),
            poolId
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
        assertEq(initiative.valkyrieIncentives(), address(valkyrie));
        assertEq(IncentivizedPoolId.unwrap(initiative.targetPoolId()), IncentivizedPoolId.unwrap(poolId));
        assertEq(initiative.pendingBudget(), 0);
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
        vm.assume(amount >= 1 ether);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();

        uint256 currentTs = block.timestamp;

        uint256 feeAmount = (valkyrie.getFeeRatio(address(initiative)) * _budget) / MAX_BPS;
        uint256 depositedBudget = _budget - feeAmount;
        uint256 rate = depositedBudget / DEFAULT_DURATION;

        vm.expectEmit(true, true, true, true);
        emit IncentiveDeposited();

        initiative.process();

        assertEq(initiative.pendingBudget(), 0);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), rate);
        assertEq(uint256(currentDistribution.endTimestamp), currentTs + DEFAULT_DURATION);
        assertEq(uint256(currentDistribution.lastUpdateTime), currentTs);
    }

    function test_process_budgetAlreadyPulled(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);
        vm.assume(amount >= 1 ether);

        deal(address(lusd), address(mockGovernance), 150e18);
        initiative.pullBudget();

        skip(3 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();

        uint256 currentTs = block.timestamp;

        uint256 feeAmount = (valkyrie.getFeeRatio(address(initiative)) * _budget) / MAX_BPS;
        uint256 depositedBudget = _budget - feeAmount;
        uint256 rate = depositedBudget / DEFAULT_DURATION;

        vm.expectEmit(true, true, true, true);
        emit IncentiveDeposited();

        initiative.process();

        assertEq(initiative.pendingBudget(), 0);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), rate);
        assertEq(uint256(currentDistribution.endTimestamp), currentTs + DEFAULT_DURATION);
        assertEq(uint256(currentDistribution.lastUpdateTime), currentTs);
    }

    function test_process_process_addToCurrentDistribution(uint256 amount) public {
        vm.assume(amount < 750 ether);
        vm.assume(amount >= 150 ether);

        deal(address(lusd), address(mockGovernance), 150e18);
        initiative.process();

        skip(10 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 currentTs = block.timestamp;

        IValkyrieBasicIncentive.RewardData memory prevDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        uint256 remainingDuration = prevDistribution.endTimestamp - block.timestamp;
        uint256 remainingBudget = prevDistribution.ratePerSec * remainingDuration;

        uint256 addedDuration = DEFAULT_DURATION - remainingDuration;

        uint256 _budget = amount + initiative.pendingBudget();

        uint256 feeAmount = (valkyrie.getFeeRatio(address(initiative)) * _budget) / MAX_BPS;
        uint256 depositedBudget = _budget - feeAmount;
        uint256 rate = (depositedBudget + remainingBudget) / DEFAULT_DURATION;
        vm.expectEmit(true, true, true, true);
        emit IncentiveDeposited();

        initiative.process();

        assertEq(initiative.pendingBudget(), 0);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), rate);
        assertEq(uint256(currentDistribution.endTimestamp), currentTs + DEFAULT_DURATION);
        assertEq(uint256(currentDistribution.lastUpdateTime), currentTs);
    }

    function test_process_afterDistributionEnded(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);
        vm.assume(amount >= 1 ether);

        deal(address(lusd), address(mockGovernance), 150e18);
        initiative.process();

        skip(20 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();

        uint256 currentTs = block.timestamp;

        uint256 feeAmount = (valkyrie.getFeeRatio(address(initiative)) * _budget) / MAX_BPS;
        uint256 depositedBudget = _budget - feeAmount;
        uint256 rate = depositedBudget / DEFAULT_DURATION;

        vm.expectEmit(true, true, true, true);
        emit IncentiveDeposited();

        initiative.process();

        assertEq(initiative.pendingBudget(), 0);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), rate);
        assertEq(uint256(currentDistribution.endTimestamp), currentTs + DEFAULT_DURATION);
        assertEq(uint256(currentDistribution.lastUpdateTime), currentTs);
    }

    function test_process_doesNothing_notEnoughBudget(uint256 amount) public {
        vm.assume(amount <= 30 ether);

        deal(address(lusd), address(mockGovernance), 150e18);
        initiative.process();

        skip(10 days);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 currentTs = block.timestamp;

        IValkyrieBasicIncentive.RewardData memory prevDistribution = valkyrie.poolRewardData(poolId, address(lusd));

        uint256 newPendingBudget = amount + initiative.pendingBudget();

        initiative.process();

        assertEq(initiative.pendingBudget(), newPendingBudget);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), uint256(prevDistribution.ratePerSec));
        assertEq(uint256(currentDistribution.endTimestamp), uint256(prevDistribution.endTimestamp));
        assertEq(uint256(currentDistribution.lastUpdateTime), uint256(prevDistribution.lastUpdateTime));
    }

    function test_process_customFeeRatio(uint256 amount) public {
        vm.assume(amount <= 999999999 ether);
        vm.assume(amount >= 1 ether);

        valkyrie.setFeeRatio(address(initiative), 50);

        deal(address(lusd), address(mockGovernance), amount);

        uint256 _budget = amount + initiative.pendingBudget();

        uint256 currentTs = block.timestamp;

        uint256 feeAmount = (valkyrie.getFeeRatio(address(initiative)) * _budget) / MAX_BPS;
        uint256 depositedBudget = _budget - feeAmount;
        uint256 rate = depositedBudget / DEFAULT_DURATION;

        vm.expectEmit(true, true, true, true);
        emit IncentiveDeposited();

        initiative.process();

        assertEq(initiative.pendingBudget(), 0);

        IValkyrieBasicIncentive.RewardData memory currentDistribution = valkyrie.poolRewardData(poolId, address(lusd));
        assertEq(uint256(currentDistribution.ratePerSec), rate);
        assertEq(uint256(currentDistribution.endTimestamp), currentTs + DEFAULT_DURATION);
        assertEq(uint256(currentDistribution.lastUpdateTime), currentTs);
    }

}