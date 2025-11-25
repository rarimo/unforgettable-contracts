// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {BaseSubscriptionManager} from "../core/subscription/BaseSubscriptionManager.sol";

import {IHelperDataSubscriptionManager} from "../interfaces/helper-data/IHelperDataSubscriptionManager.sol";

contract HelperDataSubscriptionManager is
    IHelperDataSubscriptionManager,
    BaseSubscriptionManager,
    ADeployerGuard
{
    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        HelperDataSubscriptionManagerInitData calldata initData_
    ) external initializer onlyDeployer {
        __BaseSubscriptionManager_init(
            initData_.subscriptionCreators,
            initData_.tokensPaymentInitData,
            initData_.sbtPaymentInitData,
            initData_.sigSubscriptionInitData,
            initData_.crossChainInitData
        );
    }
}
