// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {BaseSubscriptionManager} from "../core/subscription/BaseSubscriptionManager.sol";

contract AccountSubscriptionManager is BaseSubscriptionManager, ADeployerGuard {
    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        address recoveryManager_,
        TokensPaymentModuleInitData calldata tokensPaymentInitData_,
        SBTPaymentModuleInitData calldata sbtPaymentInitData_,
        SigSubscriptionModuleInitData calldata sigSubscriptionInitData_
    ) external initializer onlyDeployer {
        __BaseSubscriptionManager_init(
            recoveryManager_,
            tokensPaymentInitData_,
            sbtPaymentInitData_,
            sigSubscriptionInitData_
        );
    }
}
