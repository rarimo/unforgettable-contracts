// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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

    struct SubscribeData {
        address subscriptionManager;
        address paymentTokenAddr;
        uint64 duration;
        RecoveryMethod[] recoveryMethods;
    }

    struct RecoveryMethod {
        uint256 strategyId;
        bytes recoveryData;
    }

    struct AccountRecoveryData {
        uint256 nextRecoveryMethodId;
        EnumerableSet.UintSet activeRecoveryMethods;
        mapping(uint256 => RecoveryMethod) recoveryMethods;
    }

    error ZeroStrategyAddress();
    error InvalidStrategyStatus(StrategyStatus expectedStatus, StrategyStatus actualStatus);
    error InvalidRecoveryStrategy(address recoveryStrategy);
    error SubscriptionManagerDoesNotExist(address subscriptionManager);
    error NoActiveSubscription(address subscriptionManager, address account);
    error RecoveryMethodNotSet(address account, uint256 recoveryMethodId);
    error AccountNotSubscribed(address account);
    error AccountAlreadySubscribed(address account);
    error NoRecoveryMethodsProvided();

    event SubscriptionManagerAdded(address indexed subscriptionManager);
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    event StrategyAdded(uint256 indexed strategyId);
    event StrategyDisabled(uint256 indexed strategyId);
    event StrategyEnabled(uint256 indexed strategyId);
}
