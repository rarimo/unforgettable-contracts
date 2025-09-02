// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./subscription/IBaseSubscriptionModule.sol";

interface ISideChainSubscriptionManager is IBaseSubscriptionModule {
    struct SideChainSubscriptionManagerInitData {
        address subscriptionsStateReceiver;
        address sourceSubscriptionManager;
    }
}
