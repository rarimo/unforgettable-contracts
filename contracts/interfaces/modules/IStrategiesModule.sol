// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStrategiesModule {
    enum StrategyStatus {
        None,
        Active,
        Disabled
    }

    struct StrategyData {
        uint256 baseRecoveryCostInUsd;
        address strategy;
        StrategyStatus status;
    }

    error ZeroStrategyAddress();
    error InvalidStrategyStatus(StrategyStatus expectedStatus, StrategyStatus actualStatus);

    event StrategyAdded(uint256 indexed strategyId);
    event StrategyDisabled(uint256 indexed strategyId);
    event StrategyEnabled(uint256 indexed strategyId);
}
