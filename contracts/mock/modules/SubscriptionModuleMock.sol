// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SubscriptionModule} from "../../modules/SubscriptionModule.sol";

contract SubscriptionModuleMock is SubscriptionModule {
    function setBasePeriodDuration(uint64 newBasePeriodDuration_) external {
        _setBasePeriodDuration(newBasePeriodDuration_);
    }

    function updateSubscriptionPeriod(uint64 duration_, uint256 strategiesCostFactor_) external {
        _updateSubscriptionPeriod(duration_, strategiesCostFactor_);
    }

    function removeSubscriptionPeriod(uint64 duration_) external {
        _removeSubscriptionPeriod(duration_);
    }

    function createNewSubscription(
        address account_,
        uint256 duration_,
        uint256 recoverySecurityPercentage_,
        RecoveryMethod[] memory recoveryMethods_
    ) external returns (uint256 newSubscriptionId_) {
        return
            _createNewSubscription(
                account_,
                duration_,
                recoverySecurityPercentage_,
                recoveryMethods_
            );
    }

    function extendSubscription(uint256 subscriptionId_, uint256 duration_) external {
        _extendSubscription(subscriptionId_, duration_);
    }

    function changeRecoverySecurityPercentage(
        uint256 subscriptionId_,
        uint256 newRecoverySecurityPercentage_
    ) external {
        _changeRecoverySecurityPercentage(subscriptionId_, newRecoverySecurityPercentage_);
    }

    function changeRecoveryData(
        uint256 subscriptionId_,
        uint256 methodId_,
        bytes memory newRecoveryData_
    ) external {
        _changeRecoveryData(subscriptionId_, methodId_, newRecoveryData_);
    }

    function addRecoveryMethod(
        uint256 subscriptionId_,
        RecoveryMethod memory newRecoveryMethod_
    ) external {
        _addRecoveryMethod(subscriptionId_, newRecoveryMethod_);
    }

    function removeRecoveryMethod(uint256 subscriptionId_, uint256 methodId_) external {
        _removeRecoveryMethod(subscriptionId_, methodId_);
    }
}
