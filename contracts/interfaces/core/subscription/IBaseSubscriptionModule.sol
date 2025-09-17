// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IBaseSubscriptionModule
 * @notice Interface for the BaseSubscriptionModule contract
 */
interface IBaseSubscriptionModule {
    /**
     * @notice Data structure storing subscription details for an account.
     * @param startTime Timestamp when the subscription started.
     * @param endTime Timestamp when the subscription ends.
     */
    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
    }

    /**
     * @notice Emitted when a subscription is extended.
     * @param account The account for which the subscription was extended.
     * @param duration The duration in seconds added.
     * @param newEndTime The updated subscription end time.
     */
    event SubscriptionExtended(address indexed account, uint64 duration, uint64 newEndTime);

    /**
     * @notice A function to check if an account has a created subscription.
     * @param account_ The account to check.
     * @return `true` if the account has a subscription record, `false` otherwise.
     */
    function hasSubscription(address account_) external view returns (bool);

    /**
     * @notice A function to check if an account has an active (purchased) subscription.
     * @param account_ The account to check.
     * @return `true` if the account subscription is active, `false` otherwise.
     */
    function hasActiveSubscription(address account_) external view returns (bool);

    /**
     * @notice A function to check if an account has a subscription debt (expired but recorded).
     * @param account_ The account to check.
     * @return `true` if the account has subscription debt, `false` otherwise.
     */
    function hasSubscriptionDebt(address account_) external view returns (bool);

    /**
     * @notice A function to retrieve the subscription end time for an account.
     * @param account_ The account to query.
     * @return Timestamp when the subscription ends.
     */
    function getSubscriptionEndTime(address account_) external view returns (uint64);

    /**
     * @notice A function to retrieve the subscription start time for an account.
     * @param account_ The account to query.
     * @return Timestamp when the subscription started.
     */
    function getSubscriptionStartTime(address account_) external view returns (uint64);
}
