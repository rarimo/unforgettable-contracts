// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IRecoveryProvider} from "./IRecoveryProvider.sol";

interface IRecoveryManager is IRecoveryProvider {
    enum StrategyStatus {
        None,
        Active,
        Disabled
    }

    struct NewSubscriptionPeriodInfo {
        uint256 duration;
        uint256 strategiesCostFactor;
    }

    struct NewStrategyInfo {
        uint256 recoveryCostInUsd;
        address strategy;
    }

    struct SubscriptionPeriodData {
        uint256 strategiesCostFactor;
    }

    struct StrategyData {
        uint256 recoveryCostInUsd;
        address strategy;
        StrategyStatus status;
    }

    struct SubscribeData {
        uint256 recoverSecurityPercentage;
        RecoveryMethod[] recoveryMethods;
    }

    struct RecoveryMethod {
        uint256 strategyId;
        bytes recoveryData;
    }

    struct AccountRecoverySettings {
        uint256 recoverSecurityPercentage;
        uint256 nextRecoveryMethodId;
        EnumerableSet.UintSet activeRecoveryMethodIds;
        mapping(uint256 => RecoveryMethod) recoveryMethods;
    }

    event RecoverySecurityPercentageChanged(
        address indexed account,
        uint256 newRecoverySecurityPercentage
    );
    event NewRecoveryMethodAdded(address indexed account, uint256 indexed recoveryMethodId);
    event RecoveryMethodChanged(address indexed account, uint256 indexed recoveryMethodId);
    event RecoveryMethodRemoved(address indexed account, uint256 indexed recoveryMethodId);
}
