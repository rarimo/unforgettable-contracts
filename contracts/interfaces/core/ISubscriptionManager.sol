// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokensPaymentModule} from "./subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "./subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "./subscription/ISignatureSubscriptionModule.sol";

/**
 * @title ISubscriptionManager
 * @notice Interface for the BaseSubscriptionManager contract
 */
interface ISubscriptionManager is
    ITokensPaymentModule,
    ISBTPaymentModule,
    ISignatureSubscriptionModule
{
    /**
     * @notice Thrown when trying to create a subscription for an account that already has one.
     * @param account The account address.
     */
    error SubscriptionAlreadyCreated(address account);
    /**
     * @notice Thrown when an unauthorized sender try to create a subscription or remove
     *         themselves from subscription creators.
     * @param sender The sender address.
     */
    error NotASubscriptionCreator(address sender);
    /**
     * @notice Thrown when trying to add a subscription creator that was previously added.
     * @param subscriptionCreator The subscription creator address.
     */
    error SubscriptionCreatorAlreadyAdded(address subscriptionCreator);

    /**
     * @notice Emitted when subscription is created for the provided account.
     * @param account The account address.
     * @param startTime The start time of the newly created subscription.
     */
    event SubscriptionCreated(address indexed account, uint256 startTime);
    /**
     * @notice Emitted when subscription creator is added.
     * @param subscriptionCreator The new subscription creator address.
     */
    event SubscriptionCreatorAdded(address indexed subscriptionCreator);
    /**
     * @notice Emitted when subscription creator is removed.
     * @param subscriptionCreator The removed subscription creator address.
     */
    event SubscriptionCreatorRemoved(address indexed subscriptionCreator);

    /**
     * @notice Pauses subscription creation and management.
     */
    function pause() external;

    /**
     * @notice Resumes subscription creation and management.
     */
    function unpause() external;

    /**
     * @notice A function to create a subscription for the provided account.
     * @dev Can only be called by a valid subscription creator.
     * @param account_ The address of the account to create a subscription for.
     */
    function createSubscription(address account_) external;

    /**
     * @notice A function to retrieve the implementation address of the subscription manager.
     * @return The implementation contract address.
     */
    function implementation() external view returns (address);

    /**
     * @notice A function to retrieve a list of subscription creator addresses.
     * @return An array of all accounts authorized to create subscriptions.
     */
    function getSubscriptionCreators() external view returns (address[] memory);

    /**
     * @notice A function to check whether an account is a subscription creator.
     * @return true` if the account is a subscription creator, `false` otherwise.
     */
    function isSubscriptionCreator(address account_) external returns (bool);
}
