// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VaultSubscriptionManager} from "../../subscription/VaultSubscriptionManager.sol";

contract VaultSubscriptionManagerMock is VaultSubscriptionManager {
    function version() external pure returns (string memory) {
        return "v2.0.0";
    }
}
