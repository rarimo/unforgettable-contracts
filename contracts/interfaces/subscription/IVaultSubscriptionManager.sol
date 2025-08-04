// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "./ISubscriptionManager.sol";

import {IVaultNameSubscriptionModule} from "./modules/IVaultNameSubscriptionModule.sol";

// solhint-disable-next-line no-empty-blocks
interface IVaultSubscriptionManager is ISubscriptionManager, IVaultNameSubscriptionModule {}
