// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Safe} from "@safe-global/safe-smart-account/contracts/Safe.sol";

contract SafeMock is Safe {
    event RecoveryProviderAdded(address indexed provider);
    event RecoveryProviderRemoved(address indexed provider);
    event AccessRecovered(bytes subject);
}
