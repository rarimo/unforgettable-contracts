// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBaseSubscriptionModule {
    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
        mapping(address => uint256) accountSubscriptionCosts;
    }

    error ZeroAddr();

    event SubscriptionExtended(address indexed account, uint64 duration, uint64 newEndTime);

    function getAccountSubscriptionEndTime(address account_) external view returns (uint64);
    function hasSubscription(address account_) external view returns (bool);
    function hasActiveSubscription(address account_) external view returns (bool);
    function hasSubscriptionDebt(address account_) external view returns (bool);
}
