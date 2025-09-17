// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CrossChainModule} from "../../../../core/subscription/modules/CrossChainModule.sol";

contract CrossChainModuleMock is CrossChainModule {
    function initialize(CrossChainModuleInitData calldata initData_) external initializer {
        __CrossChainModule_init(initData_);
    }

    function setSubscriptionSynchronizer(address subscriptionSynchronizer_) external {
        _setSubscriptionSynchronizer(subscriptionSynchronizer_);
    }

    function extendSubscription(address account_, uint64 duration_) external {
        _extendSubscription(account_, duration_);
    }
}
