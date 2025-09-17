// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSideChainSubscriptionManager} from "./IBaseSideChainSubscriptionManager.sol";

/**
 * @title ISideChainSubscriptionManager
 * @notice Interface for managing subscriptions on a side chain.
 */
interface ISideChainSubscriptionManager is IBaseSideChainSubscriptionManager {
    /**
     * @notice Initialization data for the side chain subscription manager.
     */
    struct SideChainSubscriptionManagerInitData {
        BaseSideChainSubscriptionManagerInitData baseSideChainSubscriptionManagerInitData;
    }
}
