// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ISubscriptionModule {
    struct RecoveryMethod {
        uint256 strategyId;
        bytes recoveryData;
    }

    struct SubscriptionData {
        address account;
        uint256 recoverySecurityPercentage;
        uint128 nextRecoveryMethodId;
        uint64 startTime;
        uint64 endTime;
        EnumerableSet.UintSet activeRecoveryMethodIds;
        mapping(uint256 => RecoveryMethod) recoveryMethods;
    }

    error InvalidBasePeriodDuration(uint256 newBasePeriodDurationValue);
    error InvalidSubscriptionDuration(uint256 duration);
    error SubscriptionPeriodDoesNotExist(uint256 duration);
    error ZeroAccountAddress();
    error InvalidRecoverySecurityPercentage(uint256 recoverSecurityPercentage);
    error EmptyRecoveryMethodsArr();
    error NotAnActiveRecoveryMethod(uint256 subscriptionId, uint256 methodId);
    error SubscriptionDoesNotExist(uint256 subscriptionId);
    error UnableToExtendSubscription(uint256 subscriptionId);
    error UnableToRemoveLastRecoveryMethod();
    error NoActiveSubscription(address account);
    error NotAnActiveSubscription(uint256 subscriptionId);

    event RecoverySecurityPercentageSettingChanged(
        address indexed account,
        uint256 newRecoverySecurityPercentage
    );
    event BasePeriodDurationUpdated(uint256 newBasePeriodDurationValue);
    event SubscriptionPeriodUpdated(uint256 indexed duration, uint256 newPeriodFactor);
    event SubscriptionPeriodRemoved(uint256 indexed duration);

    event RecoveryMethodAdded(uint256 indexed subscriptionId, uint256 recoveryMethodId);
    event RecoveryDataChanged(uint256 indexed subscriptionId, uint256 recoveryMethodId);
    event RecoverySecurityPercentageChanged(
        uint256 indexed subscriptionId,
        uint256 recoverySecurityPercentage
    );

    event SubscriptionCreated(
        address indexed account,
        uint256 indexed subscriptionId,
        uint256 duration
    );
    event SubscriptionExtended(uint256 indexed subscriptionId, uint256 duration);
}
