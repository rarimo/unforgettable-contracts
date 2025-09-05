// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

/**
 * @title ISBTPaymentModule
 * @notice Interface for the SBTPaymentModule contract
 */
interface ISBTPaymentModule is IBaseSubscriptionModule {
    /**
     * @notice Data structure storing data used to update the SBT payment configuration.
     * @param sbt The SBT contract address.
     * @param subscriptionDurationPerToken Subscription duration in seconds added per token.
     */
    struct SBTUpdateEntry {
        address sbt;
        uint64 subscriptionDurationPerToken;
    }

    /**
     * @notice Initialization parameters for the SBTPaymentModule contract.
     * @param sbtEntries The list of supported SBTs with their subscription durations.
     */
    struct SBTPaymentModuleInitData {
        SBTUpdateEntry[] sbtEntries;
    }

    /**
     * @notice Thrown when an unsupported SBT is provided.
     * @param sbt The unsupported SBT contract address.
     */
    error NotSupportedSBT(address sbt);
    /**
     * @notice Thrown when trying to add an already supported SBT.
     * @param sbt The duplicate SBT contract address.
     */
    error SBTAlreadyAdded(address sbt);
    /**
     * @notice Thrown when a user who is not the token owner tries to use SBT.
     * @param sbt The SBT contract address.
     * @param userAddr The address attempting to use the SBT.
     * @param tokenId The token ID being checked.
     */
    error NotASBTOwner(address sbt, address userAddr, uint256 tokenId);

    /**
     * @notice Emitted when a new SBT is added.
     * @param sbt The new supported SBT contract address.
     */
    event SBTAdded(address indexed sbt);
    /**
     * @notice Emitted when an SBT is removed.
     * @param sbt The removed SBT contract address.
     */
    event SBTRemoved(address indexed sbt);
    /**
     * @notice Emitted when an SBT configuration is updated.
     * @param sbt The SBT contract address.
     * @param newDuration The updated subscription duration per SBT.
     */
    event SubscriptionDurationPerSBTUpdated(address indexed sbt, uint64 newDuration);
    /**
     * @notice Emitted when a subscription is bought using an SBT.
     * @param sbt The SBT contract address.
     * @param payer The address that paid using the SBT (SBT owner).
     * @param tokenId The token ID used for the payment.
     */
    event SubscriptionBoughtWithSBT(address indexed sbt, address indexed payer, uint256 tokenId);

    /**
     * @notice A function to buy a subscription for an account using an SBT.
     * @param account_ The account to buy a subscription for.
     * @param sbt_ The SBT contract address.
     * @param tokenId_ The token ID used for the payment.
     */
    function buySubscriptionWithSBT(address account_, address sbt_, uint256 tokenId_) external;

    /**
     * @notice A function to retrieve a list of all SBTs supported for payment.
     * @return An array of supported SBT addresses.
     */
    function getSupportedSBTs() external view returns (address[] memory);

    /**
     * @notice A function to check whether an SBT is supported for buying subscription.
     * @param sbtToken_ The SBT contract address.
     * @return `true` if the token is supported, `false` otherwise.
     */
    function isSupportedSBT(address sbtToken_) external view returns (bool);

    /**
     * @notice A function to retrieve the subscription duration granted per an SBT.
     * @param sbtToken_ The SBT contract address.
     * @return Subscription duration in seconds added per token.
     */
    function getSubscriptionDurationPerSBT(address sbtToken_) external view returns (uint64);
}
