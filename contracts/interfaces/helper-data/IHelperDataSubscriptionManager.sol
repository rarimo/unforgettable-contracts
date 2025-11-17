// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

/**
 * @title IHelperDataSubscriptionManager
 * @notice Interface for the HelperDataSubscriptionManager contract
 */
interface IHelperDataSubscriptionManager is ISubscriptionManager {
    /**
     * @notice Initialization parameters for the HelperDataSubscriptionManager contract.
     * @param subscriptionCreators Initial list of addresses allowed to create subscriptions.
     * @param tokensPaymentInitData Initialization data for the tokens payment module.
     * @param sbtPaymentInitData Initialization data for the SBT payment module.
     * @param sigSubscriptionInitData Initialization data for the signature-based subscription module.
     */
    struct HelperDataSubscriptionManagerInitData {
        address[] subscriptionCreators;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }
}
