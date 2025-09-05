// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSideChainSubscriptionManager} from "./IBaseSideChainSubscriptionManager.sol";

interface ISideChainSubscriptionManager is IBaseSideChainSubscriptionManager {
    struct SideChainSubscriptionManagerInitData {
        BaseSideChainSubscriptionManagerInitData baseSideChainSubscriptionManagerInitData;
    }
}
