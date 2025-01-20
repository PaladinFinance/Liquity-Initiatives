// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BribeInitiative } from "liquity-gov/src/BribeInitiative.sol";
import { Ownable2Step } from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultiRecipientInitiative is BribeInitiative, Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 private constant BPS = 10000;

    constructor(
        address _governance, address _bold, address _bribeToken
    ) BribeInitiative(_governance, _bold, _bribeToken) Ownable(msg.sender) {
        
    }

    function process() external {
        _pullBudget();
        _distribute();
    }

    function pullBudget() external {
        _pullBudget();
    }

    function _pullBudget() internal {
        uint256 amount = governance.claimForInitiative(address(this));
        pendingBudget += amount;
    }
 
}