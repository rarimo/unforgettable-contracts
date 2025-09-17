// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

/**
 * @title IAccountSubscriptionManager
 * @notice Interface for the AccountSubscriptionManager contract
 */
interface IAccountSubscriptionManager is ISubscriptionManager {
    /**
     * @notice Initialization parameters for the AccountSubscriptionManager contract.
     * @param subscriptionCreators Initial list of addresses allowed to create subscriptions.
     * @param tokensPaymentInitData Initialization data for the tokens payment module.
     * @param sbtPaymentInitData Initialization data for the SBT payment module.
     * @param sigSubscriptionInitData Initialization data for the signature-based subscription module.
     */
    struct AccountSubscriptionManagerInitData {
        address[] subscriptionCreators;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }

    /**
     * @notice A function to grant the ability to create subscriptions to the provided addresses.
     * @param subscriptionCreators_ The list of addresses to be added as subscription creators.
     */
    function addSubscriptionCreators(address[] calldata subscriptionCreators_) external;

    /**
     * @notice A function to revoke the ability to create subscriptions from the provided addresses.
     * @param subscriptionCreators_ The list of addresses to be removed from subscription creators.
     */
    function removeSubscriptionCreators(address[] calldata subscriptionCreators_) external;
}
