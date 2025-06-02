# Quest Initiative Guide

## Constructor parameters : 

```solidity
constructor(
    address _governance,
    address _bold,
    address _bribeToken,
    address _board,
    address _gauge
)
```

- `_governance`: Address of the Liquity governance contract.
- `_bold`: Address of the BOLD token.
- `_bribeToken`: Address of the token used to pay bribes.
- `_board`: Address of the Quest board contract.
- `_gauge`: Address of the gauge (veBAL or veCRV) that will receive incentivized votes.  
  
  
### Quest Boards : 
- veBAL (& vlAURA) : `0xfEb352930cA196a80B708CDD5dcb4eCA94805daB`
- veCRV (& vlCVX) : `0xAa1698f0A51e6d00F5533cc3E5D36010ee4558C6`


## Parameters functions : 

```solidity
struct QuestSettings {
    uint256 minRewardPerVote;
    uint256 maxRewardPerVote;
    IQuestBoard.QuestVoteType voteType;
    IQuestBoard.QuestCloseType closeType;
}
```
- `minRewardPerVote`: Minimum amount of reward token for 1 vote (here in BOLD/veToken)
- `maxRewardPerVote`: Maximum amount of reward token for 1 vote (here in BOLD/veToken)
- `voteType`: Types of Vote logic for Quests :
    - `NORMAL`: all voters allowed
    - `BLACKLIST`: listed voters are removed from rewards
    - `WHITELIST`: only listed voters will be rewarded
- `closeType`: Types of logic for undistributed rewards when closing Quest periods
    - `NORMAL`: undistributed rewards are available to be withdrawn by the creator 
    - `ROLLOVER`: undistributed rewards are added to the next period, increasing the reward/vote parameter
    - `DISTRIBUTE`: undistributed rewards are sent to the gauge for direct distribution  


```solidity
address[] public questVoterList;
```
List of addresses for the vote types. Used for `WHITELIST` and `BLACKLIST` vote types.

### Functions to set & update those parameters : 

```solidity
function updateQuestSettings(
    uint256 _minRewardPerVote,
    uint256 _maxRewardPerVote,
    IQuestBoard.QuestVoteType _voteType,
    IQuestBoard.QuestCloseType _closeType,
    address[] memory _voterList
)
```
(must be called before the 1st Quest is created, otherwise it will revert).  

```solidity
function updateQuestRewardPerVote(
    uint256 _minRewardPerVote,
    uint256 _maxRewardPerVote
)
```

```solidity
function updateQuestTypeSettings(
    IQuestBoard.QuestVoteType _voteType,
    IQuestBoard.QuestCloseType _closeType,
    address[] memory _voterList
)
```


## Management functions :

```solidity
function pullBudget()
```
Will simply pull the budget from the governance contract, which is used to pay for the bribes. 
This can be used during off weeks to simply pull the budget without trying to create a Quest.  


```solidity
function process()
```
Will pull any budget from the governance contract, and then try to create a Quest with the current total budget
and the current `QuestSettings`. This will also try to recover any unspent budget from the previous Quest, if any is left.
In case the last created Quest is still active, it will not create a new one and simply return.  


```solidity
function depositBribe(uint256 _boldAmount, uint256 _bribeTokenAmount, uint256 _epoch)
```
Deposit a bribe.  
Parameters : 
- `_boldAmount`: Amount of BOLD tokens to deposit
- `_bribeTokenAmount` : Amount of bribe tokens to deposit
- `_epoch` : Epoch at which the bribe is deposited
(For more informations, see the Liquity documentation on bribes and epochs)  
