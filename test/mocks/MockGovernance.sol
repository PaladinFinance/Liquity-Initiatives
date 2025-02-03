// SPDX-License-Identifier: None

pragma solidity 0.8.24;

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockGovernance {
    using SafeERC20 for IERC20;

    uint256 private __epoch;

    uint256 public constant EPOCH_START = 0;
    uint256 public constant EPOCH_DURATION = 7 days;

    address public token;

    constructor(address _token) {
        token = _token;
    }

    function claimForInitiative(address _initiative) external returns (uint256) {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(_initiative, amount);
        return amount;
    }

    function setEpoch(uint256 _epoch) external {
        __epoch = _epoch;
    }

    function epoch() external view returns (uint256) {
        return __epoch;
    }
}