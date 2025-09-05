// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IRecoveryProvider} from "@solarity/solidity-lib/interfaces/account-abstraction/IRecoveryProvider.sol";

/**
 * @title IRecoveryManager
 * @notice Interface for the RecoveryManager contract
 */
interface IRecoveryManager is IRecoveryProvider {
    enum StrategyStatus {
        None,
        Active,
        Disabled
    }

    /**
     * @notice Data structure storing recovery strategy data.
     * @param strategy The strategy contract address.
     * @param status The current status of the strategy.
     */
    struct StrategyData {
        address strategy;
        StrategyStatus status;
    }

    /**
     * @notice Data structure storing data provided when an account subscribes to a recovery manager.
     * @param subscriptionManager The subscription manager address to verify or purchase a subscription.
     * @param paymentTokenAddr The ERC-20 or ETH token address to pay for the subscription (optional).
     * @param duration Subscription duration in seconds (optional).
     * @param recoveryMethods The list of recovery methods to add when subscribing.
     */
    struct SubscribeData {
        address subscriptionManager;
        address paymentTokenAddr;
        uint64 duration;
        RecoveryMethod[] recoveryMethods;
    }

    /**
     * @notice Data structure storing recovery method data.
     * @param strategyId The ID of the recovery strategy.
     * @param recoveryData Encoded strategy-specific recovery data.
     */
    struct RecoveryMethod {
        uint256 strategyId;
        bytes recoveryData;
    }

    /**
     * @notice Data structure storing per-account recovery data.
     * @param nextRecoveryMethodId Incremental counter for the recovery method IDs.
     * @param activeRecoveryMethods The set of active recovery method IDs.
     * @param recoveryMethods Mapping of the recovery method IDs to their actual recovery data.
     */
    struct AccountRecoveryData {
        uint256 nextRecoveryMethodId;
        EnumerableSet.UintSet activeRecoveryMethods;
        mapping(uint256 => RecoveryMethod) recoveryMethods;
    }

    /**
     * @notice Thrown when zero strategy address is provided.
     */
    error ZeroStrategyAddress();
    /**
     * @notice Thrown when a strategy has invalid status.
     * @param expectedStatus The expected strategy status.
     * @param actualStatus The current strategy status.
     */
    error InvalidStrategyStatus(StrategyStatus expectedStatus, StrategyStatus actualStatus);
    /**
     * @notice Thrown when a recovery provider stored in the provided strategy is not address(this).
     * @param recoveryStrategy Invalid recovery strategy address.
     */
    error InvalidRecoveryStrategy(address recoveryStrategy);
    /**
     * @notice Thrown when a subscription manager is not whitelisted.
     * @param subscriptionManager Invalid subscription manager address.
     */
    error SubscriptionManagerDoesNotExist(address subscriptionManager);
    /**
     * @notice Thrown when an account doesn't have an active subscription.
     * @param subscriptionManager The subscription manager address.
     * @param account The account address.
     */
    error NoActiveSubscription(address subscriptionManager, address account);
    /**
     * @notice Thrown when an account doesn't have a specific recovery method registered.
     * @param account The account address.
     * @param recoveryMethodId Invalid recovery method ID.
     */
    error RecoveryMethodNotSet(address account, uint256 recoveryMethodId);
    /**
     * @notice Thrown when trying to unsubscribe an account that has not been subscribed yet.
     * @param account The account address.
     */
    error AccountNotSubscribed(address account);
    /**
     * @notice Thrown when trying to subscribe an already subscribed account.
     * @param account The account address.
     */
    error AccountAlreadySubscribed(address account);
    /**
     * @notice Thrown when no recovery methods are provided during subscribing.
     */
    error NoRecoveryMethodsProvided();

    /**
     * @notice Emitted when a subscription manager is added.
     * @param subscriptionManager The subscription manager address whitelisted.
     */
    event SubscriptionManagerAdded(address indexed subscriptionManager);
    /**
     * @notice Emitted when a subscription manager is removed.
     * @param subscriptionManager The subscription manager address removed from the whitelist.
     */
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    /**
     * @notice Emitted when a recovery strategy is added.
     * @param strategyId The recovery strategy ID whitelisted.
     */
    event StrategyAdded(uint256 indexed strategyId);
    /**
     * @notice Emitted when a recovery strategy is disabled.
     * @param strategyId The recovery strategy ID disabled.
     */
    event StrategyDisabled(uint256 indexed strategyId);
    /**
     * @notice Emitted when a recovery strategy is enabled.
     * @param strategyId The recovery strategy ID enabled.
     */
    event StrategyEnabled(uint256 indexed strategyId);

    /**
     * @notice A function to add or remove subscription managers.
     * @param subscriptionManagersToUpdate_ The addresses to add or remove.
     * @param isAdding_ `true` if the subscription managers are being added, `false` otherwise.
     */
    function updateSubscriptionManagers(
        address[] calldata subscriptionManagersToUpdate_,
        bool isAdding_
    ) external;

    /**
     * @notice A function to add new recovery strategies.
     * @param newStrategies_ Addresses of recovery strategy contracts to add.
     */
    function addRecoveryStrategies(address[] calldata newStrategies_) external;

    /**
     * @notice A function to disable a recovery strategy.
     * @param strategyId_ The ID of the strategy to disable.
     */
    function disableStrategy(uint256 strategyId_) external;

    /**
     * @notice A function to enable a recovery strategy.
     * @param strategyId_ The ID of the strategy to enable.
     */
    function enableStrategy(uint256 strategyId_) external;

    /**
     * @notice A function to resubscribe an account with updated subscription data.
     * @dev Under the hood, simply calls unsubscribe and subscribe.
     * @param recoveryData_ Encoded `SubscribeData` containing updated subscription info.
     */
    function resubscribe(bytes memory recoveryData_) external payable;

    /**
     * @notice A function to retrieve all recovery methods of an account.
     * @param account_ The account to query.
     * @return recoveryMethods_ The list of recovery methods as `RecoveryMethod` structs.
     */
    function getRecoveryMethods(
        address account_
    ) external view returns (RecoveryMethod[] memory recoveryMethods_);

    /**
     * @notice A function to check whether a subscription manager is whitelisted.
     * @param subscriptionManager_ The subscription manager address to check.
     * @return `true` if the subscription manager exists, `false` otherwise.
     */
    function subscriptionManagerExists(address subscriptionManager_) external view returns (bool);

    /**
     * @notice A function to retrieve the status of the recovery strategy.
     * @param strategyId_ The recovery strategy ID to query.
     * @return The `StrategyStatus` of the strategy.
     */
    function getStrategyStatus(uint256 strategyId_) external view returns (StrategyStatus);

    /**
     * @notice A function to retrieve the recovery strategy address for the provided ID.
     * @param strategyId_ The recovery strategy ID to query.
     * @return The address of the strategy contract.
     */
    function getStrategy(uint256 strategyId_) external view returns (address);

    /**
     * @notice A function to check whether the strategy status is active.
     * @param strategyId_ The recovery strategy ID.
     * @return `true` if the strategy is active, `false` otherwise.
     */
    function isActiveStrategy(uint256 strategyId_) external view returns (bool);
}
