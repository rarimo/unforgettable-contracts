// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRecoveryProvider} from "@solarity/solidity-lib/interfaces/account-abstraction/IRecoveryProvider.sol";

interface IRecoveryManager is IRecoveryProvider {
    enum StrategyStatus {
        None,
        Active,
        Disabled
    }

    struct StrategyData {
        address strategy;
        StrategyStatus status;
    }

    error ZeroStrategyAddress();
    error InvalidStrategyStatus(StrategyStatus expectedStatus, StrategyStatus actualStatus);

    event SubscriptionManagerAdded(address indexed subscriptionManager);
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    event StrategyAdded(uint256 indexed strategyId);
    event StrategyDisabled(uint256 indexed strategyId);
    event StrategyEnabled(uint256 indexed strategyId);

    function getSubscribeCost(bytes memory recoveryData_) external view returns (uint256, address);
}
