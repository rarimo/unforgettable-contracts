// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "../../../interfaces/core/subscription/IBaseSubscriptionModule.sol";
import {ZeroAddressChecker} from "../../../utils/ZeroAddressChecker.sol";

contract BaseSubscriptionModule is IBaseSubscriptionModule, ZeroAddressChecker {
    bytes32 private constant BASE_SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.subscription.module.storage");

    struct BaseSubscriptionModuleStorage {
        mapping(address => AccountSubscriptionData) accountsSubscriptionData;
    }

    function _getBaseSubscriptionModuleStorage()
        private
        pure
        returns (BaseSubscriptionModuleStorage storage _bsms)
    {
        bytes32 slot_ = BASE_SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly ("memory-safe") {
            _bsms.slot := slot_
        }
    }

    /// @inheritdoc IBaseSubscriptionModule
    function hasSubscription(address account_) public view virtual returns (bool) {
        return getSubscriptionStartTime(account_) > 0;
    }

    /// @inheritdoc IBaseSubscriptionModule
    function hasActiveSubscription(address account_) public view virtual returns (bool) {
        return block.timestamp < getSubscriptionEndTime(account_);
    }

    /// @inheritdoc IBaseSubscriptionModule
    function hasSubscriptionDebt(address account_) public view virtual returns (bool) {
        return !hasActiveSubscription(account_) && hasSubscription(account_);
    }

    /// @inheritdoc IBaseSubscriptionModule
    function getSubscriptionStartTime(address account_) public view virtual returns (uint64) {
        return _getAccountSubscriptionData(account_).startTime;
    }

    /// @inheritdoc IBaseSubscriptionModule
    function getSubscriptionEndTime(address account_) public view virtual returns (uint64) {
        if (!hasSubscription(account_)) {
            return uint64(block.timestamp);
        }

        return _getAccountSubscriptionData(account_).endTime;
    }

    function _extendSubscription(address account_, uint64 duration_) internal virtual {
        uint64 subscriptionEndTime_ = getSubscriptionEndTime(account_);
        uint64 newEndTime_ = subscriptionEndTime_ + duration_;

        if (!hasSubscription(account_)) {
            _setStartTime(account_, uint64(block.timestamp));
        }

        _setEndTime(account_, newEndTime_);

        emit SubscriptionExtended(account_, duration_, newEndTime_);
    }

    function _setStartTime(address account_, uint64 newStartTime_) internal virtual {
        _getAccountSubscriptionData(account_).startTime = newStartTime_;
    }

    function _setEndTime(address account_, uint64 newEndTime_) internal virtual {
        _getAccountSubscriptionData(account_).endTime = newEndTime_;
    }

    function _getAccountSubscriptionData(
        address account_
    ) private view returns (AccountSubscriptionData storage) {
        return _getBaseSubscriptionModuleStorage().accountsSubscriptionData[account_];
    }
}
