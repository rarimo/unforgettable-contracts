// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

interface IAccountSubscriptionManager is ISubscriptionManager {
    struct AccountSubscriptionManagerInitData {
        address[] subscriptionCreators;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }

    function addSubscriptionCreators(address[] calldata subscriptionCreators_) external;

    function removeSubscriptionCreators(address[] calldata subscriptionCreators_) external;
}
