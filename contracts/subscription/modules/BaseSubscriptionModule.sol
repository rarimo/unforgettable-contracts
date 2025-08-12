// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "../../interfaces/subscription/modules/IBaseSubscriptionModule.sol";

contract BaseSubscriptionModule is IBaseSubscriptionModule {
    bytes32 public constant BASE_SUBSCRIPTION_MODULE_STORAGE_SLOT =
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

        assembly {
            _bsms.slot := slot_
        }
    }

    function getAccountSubscriptionEndTime(address account_) public view returns (uint64) {
        AccountSubscriptionData storage accountData = _getAccountSubscriptionData(account_);

        if (accountData.startTime == 0) {
            return uint64(block.timestamp);
        }

        return accountData.endTime;
    }

    function hasSubscription(address account_) public view returns (bool) {
        return _getAccountSubscriptionData(account_).startTime != 0;
    }

    function hasActiveSubscription(address account_) public view returns (bool) {
        return block.timestamp < _getAccountSubscriptionData(account_).endTime;
    }

    function hasSubscriptionDebt(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getAccountSubscriptionData(account_);

        return block.timestamp >= accountData.endTime && accountData.startTime > 0;
    }

    function _extendSubscription(address account_, uint64 duration_) internal {
        AccountSubscriptionData storage accountData = _getAccountSubscriptionData(account_);

        uint64 subscriptionEndTime_ = getAccountSubscriptionEndTime(account_);
        uint64 newEndTime_ = subscriptionEndTime_ + duration_;

        if (accountData.startTime == 0) {
            accountData.startTime = uint64(block.timestamp);
        }

        accountData.endTime = newEndTime_;

        emit SubscriptionExtended(account_, duration_, newEndTime_);
    }

    function _getAccountSubscriptionData(
        address account_
    ) internal view returns (AccountSubscriptionData storage) {
        return _getBaseSubscriptionModuleStorage().accountsSubscriptionData[account_];
    }

    function _checkAddress(address addr_) internal pure {
        require(addr_ != address(0), ZeroAddr());
    }
}
