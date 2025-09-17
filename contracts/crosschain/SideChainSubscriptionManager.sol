// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {BaseSideChainSubscriptionManager} from "../core/subscription/BaseSideChainSubscriptionManager.sol";

import {ISideChainSubscriptionManager} from "../interfaces/core/ISideChainSubscriptionManager.sol";

contract SideChainSubscriptionManager is
    ISideChainSubscriptionManager,
    BaseSideChainSubscriptionManager,
    ADeployerGuard
{
    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        SideChainSubscriptionManagerInitData calldata initData_
    ) external initializer onlyDeployer {
        __BaseSideChainSubscriptionManager_init(
            initData_.baseSideChainSubscriptionManagerInitData
        );
    }
}
