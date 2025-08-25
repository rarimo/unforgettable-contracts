// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../interfaces/core/ISubscriptionManager.sol";

contract RecoveryManagerMock {
    function createSubscription(address subscriptionManager_, address account_) external {
        ISubscriptionManager(subscriptionManager_).createSubscription(account_);
    }

    function subscribe(bytes memory recoveryData_) external payable {}

    function recover(bytes memory object_, bytes memory proof_) external {}
}
