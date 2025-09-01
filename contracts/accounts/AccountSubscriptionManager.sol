// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {BaseSubscriptionManager} from "../core/subscription/BaseSubscriptionManager.sol";

import {IAccountSubscriptionManager} from "../interfaces/accounts/IAccountSubscriptionManager.sol";

contract AccountSubscriptionManager is
    IAccountSubscriptionManager,
    BaseSubscriptionManager,
    ADeployerGuard
{
    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        AccountSubscriptionManagerInitData calldata initData_
    ) external initializer onlyDeployer {
        __BaseSubscriptionManager_init(
            initData_.subscriptionCreators,
            initData_.tokensPaymentInitData,
            initData_.sbtPaymentInitData,
            initData_.sigSubscriptionInitData
        );
    }

    /// @inheritdoc IAccountSubscriptionManager
    function addSubscriptionCreators(address[] calldata subscriptionCreators_) external onlyOwner {
        for (uint256 i = 0; i < subscriptionCreators_.length; ++i) {
            _addSubscriptionCreator(subscriptionCreators_[i]);
        }
    }

    /// @inheritdoc IAccountSubscriptionManager
    function removeSubscriptionCreators(
        address[] calldata subscriptionCreators_
    ) external onlyOwner {
        for (uint256 i = 0; i < subscriptionCreators_.length; ++i) {
            _removeSubscriptionCreator(subscriptionCreators_[i]);
        }
    }
}
