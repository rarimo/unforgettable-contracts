// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseSubscriptionModule} from "../../../../core/subscription/modules/BaseSubscriptionModule.sol";

contract BaseSubscriptionModuleMock is BaseSubscriptionModule {
    function extendSubscription(address account_, uint64 duration_) external {
        _extendSubscription(account_, duration_);
    }
}
