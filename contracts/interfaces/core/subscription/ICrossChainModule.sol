// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

/**
 * @title ICrossChainModule
 * @notice Interface for cross-chain subscription modules.
 */
interface ICrossChainModule is IBaseSubscriptionModule {
    /**
     * @notice Initialization data for the cross-chain module.
     * @param subscriptionsSynchronizer The address of the subscriptions synchronizer.
     */
    struct CrossChainModuleInitData {
        address subscriptionsSynchronizer;
    }

    /**
     * @notice Event emitted when the subscription synchronizer is updated.
     * @param subscriptionSynchronizer The address of the updated subscription synchronizer.
     */
    event SubscriptionSynchronizerUpdated(address indexed subscriptionSynchronizer);

    /**
     * @notice A function to retrieve the subscription syncronizer address.
     * @return The subscription synchronizer address.
     */
    function getSubscriptionsSynchronizer() external view returns (address);
}
