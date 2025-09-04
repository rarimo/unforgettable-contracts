// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBaseSubscriptionModule {
    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
    }

    event SubscriptionExtended(address indexed account, uint64 duration, uint64 newEndTime);

    function hasSubscription(address account_) external view returns (bool);

    function hasActiveSubscription(address account_) external view returns (bool);

    function hasSubscriptionDebt(address account_) external view returns (bool);

    function getSubscriptionEndTime(address account_) external view returns (uint64);

    function getSubscriptionStartTime(address account_) external view returns (uint64);
}
