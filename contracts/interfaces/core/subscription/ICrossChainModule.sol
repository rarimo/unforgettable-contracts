// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

interface ICrossChainModule is IBaseSubscriptionModule {
    struct CrossChainModuleInitData {
        address subscriptionsSynchronizer;
    }

    event SubscriptionSynchronizerUpdated(address indexed subscriptionSynchronizer);
}
