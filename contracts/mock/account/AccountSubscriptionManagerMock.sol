// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccountSubscriptionManager} from "../../accounts/AccountSubscriptionManager.sol";

contract AccountSubscriptionManagerMock is AccountSubscriptionManager {
    function version() external pure returns (string memory) {
        return "v2.2.1";
    }
}
