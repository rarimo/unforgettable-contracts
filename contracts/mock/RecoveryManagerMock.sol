// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../interfaces/core/ISubscriptionManager.sol";

contract RecoveryManagerMock {
    function createSubscription(address subscriptionManager_, address account_) external {
        ISubscriptionManager(subscriptionManager_).createSubscription(account_);
    }
}
