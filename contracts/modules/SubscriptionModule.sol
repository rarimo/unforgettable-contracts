// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IRecoveryStrategy} from "../interfaces/IRecoveryStrategy.sol";
import {ISubscriptionModule} from "../interfaces/modules/ISubscriptionModule.sol";

contract SubscriptionModule is ISubscriptionModule {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.strategies.module.storage");

    struct SubscriptionModuleStorage {
        uint256 lastSubscriptionId;
        uint64 basePeriodDuration;
        EnumerableSet.UintSet activeSubscriptionPeriods;
        mapping(uint64 => uint256) subscriptionPeriodsFactor;
        mapping(address => EnumerableSet.UintSet) accountSubscriptionIds;
        mapping(uint256 => SubscriptionData) subscriptionsData;
    }

    modifier onlyExistingSubscriptionPeriod(uint256 duration_) {
        _onlyExistingSubscriptionPeriod(duration_);
        _;
    }

    function _getSubscriptionModuleStorage()
        private
        pure
        returns (SubscriptionModuleStorage storage _sms)
    {
        bytes32 slot_ = SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly {
            _sms.slot := slot_
        }
    }

    function getSubscriptionAccount(uint256 subscriptionId_) public view returns (address) {
        return _getSubscriptionModuleStorage().subscriptionsData[subscriptionId_].account;
    }

    function getSubscriptionRecoverySecurityPercentage(
        uint256 subscriptionId_
    ) public view returns (uint256) {
        return
            _getSubscriptionModuleStorage()
                .subscriptionsData[subscriptionId_]
                .recoverySecurityPercentage;
    }

    function getActiveRecoveryMethod(
        uint256 subscriptionId_,
        uint256 recoveryMethodId_
    ) public view returns (RecoveryMethod memory) {
        _onlyActiveRecoveryMethod(subscriptionId_, recoveryMethodId_);

        return
            _getSubscriptionModuleStorage().subscriptionsData[subscriptionId_].recoveryMethods[
                recoveryMethodId_
            ];
    }

    function getSubscriptionActiveRecoveryMethods(
        uint256 subscriptionId_
    ) public view returns (RecoveryMethod[] memory recoveryMethods_) {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];
        EnumerableSet.UintSet storage activeMethodIds_ = subscriptionData.activeRecoveryMethodIds;

        uint256 methodIdsCount_ = activeMethodIds_.length();
        recoveryMethods_ = new RecoveryMethod[](methodIdsCount_);

        for (uint256 i = 0; i < methodIdsCount_; i++) {
            recoveryMethods_[i] = subscriptionData.recoveryMethods[activeMethodIds_.at(i)];
        }
    }

    function getAccountSubscriptionsEndTime(address account_) public view returns (uint256) {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        uint256 currentSubscriptionId_ = getLastAccountSubscriptionId(account_);

        if (currentSubscriptionId_ == 0) {
            return block.timestamp;
        }

        return $.subscriptionsData[currentSubscriptionId_].endTime;
    }

    function getLastAccountSubscriptionId(address account_) public view returns (uint256) {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        uint256 subscriptionsCount_ = $.accountSubscriptionIds[account_].length();
        if (subscriptionsCount_ == 0) {
            return 0;
        }

        return $.accountSubscriptionIds[account_].at(subscriptionsCount_ - 1);
    }

    function getCurrentAccountSubscriptionId(
        address account_
    ) public view returns (uint256 subscriptionId_) {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();
        EnumerableSet.UintSet storage subscriptionIds = $.accountSubscriptionIds[account_];

        uint256 subscriptionsCount_ = subscriptionIds.length();
        if (subscriptionsCount_ == 0) {
            return 0;
        }

        for (uint256 i = 0; i < subscriptionsCount_; i++) {
            subscriptionId_ = subscriptionIds.at(i);

            if (
                $.subscriptionsData[subscriptionId_].startTime < block.timestamp &&
                block.timestamp > $.subscriptionsData[subscriptionId_].endTime
            ) {
                break;
            }
        }
    }

    function getLeftPeriodsInSubscription(
        uint256 subscriptionId_
    ) public view returns (uint256 periodsCount_) {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        uint256 startTime_ = Math.max(subscriptionData.startTime, block.timestamp);
        uint256 endTime_ = Math.max(subscriptionData.endTime, block.timestamp);

        return getPeriodsCountByTime(endTime_ - startTime_);
    }

    function getPeriodsCountByTime(uint256 time_) public view returns (uint256 periodsCount_) {
        uint256 periodDuration_ = getBasePeriodDuration();

        periodsCount_ = time_ / periodDuration_ + 1;

        if (time_ % periodDuration_ == 0) {
            periodsCount_--;
        }
    }

    function getBasePeriodDuration() public view returns (uint256) {
        return _getSubscriptionModuleStorage().basePeriodDuration;
    }

    function getSubscriptionPeriodFactor(uint256 duration_) public view returns (uint256) {
        return _getSubscriptionModuleStorage().subscriptionPeriodsFactor[uint64(duration_)];
    }

    function subscriptionPeriodExists(uint256 duration_) public view returns (bool) {
        return _getSubscriptionModuleStorage().activeSubscriptionPeriods.contains(duration_);
    }

    function _setBasePeriodDuration(uint64 newBasePeriodDuration_) internal {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        require(
            newBasePeriodDuration_ > $.basePeriodDuration,
            InvalidBasePeriodDuration(newBasePeriodDuration_)
        );

        $.basePeriodDuration = newBasePeriodDuration_;

        emit BasePeriodDurationUpdated(newBasePeriodDuration_);
    }

    function _updateSubscriptionPeriod(uint64 duration_, uint256 strategiesCostFactor_) internal {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        require(duration_ % $.basePeriodDuration == 0, InvalidSubscriptionDuration(duration_));

        $.activeSubscriptionPeriods.add(duration_);
        $.subscriptionPeriodsFactor[duration_] = strategiesCostFactor_;

        emit SubscriptionPeriodUpdated(duration_, strategiesCostFactor_);
    }

    function _removeSubscriptionPeriod(uint64 duration_) internal {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        _onlyExistingSubscriptionPeriod(duration_);

        $.activeSubscriptionPeriods.remove(duration_);
        delete $.subscriptionPeriodsFactor[duration_];

        emit SubscriptionPeriodRemoved(duration_);
    }

    function _createNewSubscription(
        address account_,
        uint256 duration_,
        uint256 recoverySecurityPercentage_,
        RecoveryMethod[] memory recoveryMethods_
    ) internal returns (uint256 newSubscriptionId_) {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        require(account_ != address(0), ZeroAccountAddress());
        require(recoveryMethods_.length > 0, EmptyRecoveryMethodsArr());

        _onlyExistingSubscriptionPeriod(duration_);

        newSubscriptionId_ = ++$.lastSubscriptionId;
        uint256 newSubscriptionStartTime_ = getAccountSubscriptionsEndTime(account_);

        $.accountSubscriptionIds[account_].add(newSubscriptionId_);
        SubscriptionData storage subscriptionData = $.subscriptionsData[newSubscriptionId_];

        subscriptionData.account = account_;
        subscriptionData.startTime = uint64(newSubscriptionStartTime_);
        subscriptionData.endTime = uint64(newSubscriptionStartTime_ + duration_);

        _changeRecoverySecurityPercentage(newSubscriptionId_, recoverySecurityPercentage_);

        for (uint256 i = 0; i < recoveryMethods_.length; i++) {
            _addRecoveryMethod(newSubscriptionId_, recoveryMethods_[i]);
        }

        emit SubscriptionCreated(account_, newSubscriptionId_, duration_);
    }

    function _extendSubscription(uint256 subscriptionId_, uint256 duration_) internal {
        SubscriptionModuleStorage storage $ = _getSubscriptionModuleStorage();

        SubscriptionData storage subscriptionData = $.subscriptionsData[subscriptionId_];

        require(subscriptionData.account != address(0), SubscriptionDoesNotExist(subscriptionId_));
        require(
            getLastAccountSubscriptionId(subscriptionData.account) == subscriptionId_,
            UnableToExtendSubscription(subscriptionId_)
        );
        _onlyExistingSubscriptionPeriod(duration_);

        subscriptionData.endTime += uint64(duration_);

        emit SubscriptionExtended(subscriptionId_, duration_);
    }

    function _changeRecoverySecurityPercentage(
        uint256 subscriptionId_,
        uint256 newRecoverySecurityPercentage_
    ) internal {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        require(
            newRecoverySecurityPercentage_ > 0 && newRecoverySecurityPercentage_ <= PERCENTAGE_100,
            InvalidRecoverySecurityPercentage(newRecoverySecurityPercentage_)
        );

        subscriptionData.recoverySecurityPercentage = newRecoverySecurityPercentage_;

        emit RecoverySecurityPercentageChanged(subscriptionId_, newRecoverySecurityPercentage_);
    }

    function _changeRecoveryData(
        uint256 subscriptionId_,
        uint256 methodId_,
        bytes memory newRecoveryData_
    ) internal {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        _onlyActiveRecoveryMethod(subscriptionId_, methodId_);

        subscriptionData.recoveryMethods[methodId_].recoveryData = newRecoveryData_;

        emit RecoveryDataChanged(subscriptionId_, methodId_);
    }

    function _addRecoveryMethod(
        uint256 subscriptionId_,
        RecoveryMethod memory newRecoveryMethod_
    ) internal {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        uint256 newMethodId_ = subscriptionData.nextRecoveryMethodId++;

        subscriptionData.activeRecoveryMethodIds.add(newMethodId_);
        subscriptionData.recoveryMethods[newMethodId_] = newRecoveryMethod_;

        emit RecoveryMethodAdded(subscriptionId_, newMethodId_);
    }

    function _removeRecoveryMethod(uint256 subscriptionId_, uint256 methodId_) internal {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        _onlyActiveRecoveryMethod(subscriptionId_, methodId_);

        subscriptionData.activeRecoveryMethodIds.remove(methodId_);

        require(
            subscriptionData.activeRecoveryMethodIds.length() > 0,
            UnableToRemoveLastRecoveryMethod()
        );
    }

    function _hasActiveSubscription(address account_) internal view {
        require(
            getAccountSubscriptionsEndTime(account_) > block.timestamp,
            NoActiveSubscription(account_)
        );
    }

    function _onlyExistingSubscriptionPeriod(uint256 duration_) internal view {
        require(subscriptionPeriodExists(duration_), SubscriptionPeriodDoesNotExist(duration_));
    }

    function _onlyActiveRecoveryMethod(uint256 subscriptionId_, uint256 methodId_) internal view {
        require(
            _getSubscriptionModuleStorage()
                .subscriptionsData[subscriptionId_]
                .activeRecoveryMethodIds
                .contains(methodId_),
            NotAnActiveRecoveryMethod(subscriptionId_, methodId_)
        );
    }

    function _onlyActiveSubscription(uint256 subscriptionId_) internal view {
        SubscriptionData storage subscriptionData = _getSubscriptionModuleStorage()
            .subscriptionsData[subscriptionId_];

        require(
            subscriptionData.startTime <= block.timestamp &&
                block.timestamp < subscriptionData.endTime,
            NotAnActiveSubscription(subscriptionId_)
        );
    }
}
