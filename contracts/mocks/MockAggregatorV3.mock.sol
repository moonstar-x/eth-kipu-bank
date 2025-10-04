// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @dev This mock AggregatorV3 is for testing purposes only, generated with AI.
 */
contract MockAggregatorV3 is AggregatorV3Interface {
    int256 public s_answer;
    uint256 public s_updatedAt;

    function setLatestRoundData(int256 _answer, uint256 _updatedAt) external {
        s_answer = _answer;
        s_updatedAt = _updatedAt;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, s_answer, 0, s_updatedAt, 0);
    }

    function decimals() external pure override returns (uint8) {
        return 8;
    }
    function description() external pure override returns (string memory) {
        return "";
    }
    function version() external pure override returns (uint256) {
        return 1;
    }
    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}
