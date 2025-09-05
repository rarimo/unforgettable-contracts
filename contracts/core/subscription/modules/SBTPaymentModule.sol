// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IBurnableSBT} from "../../../interfaces/tokens/IBurnableSBT.sol";
import {ISBTPaymentModule} from "../../../interfaces/core/subscription/ISBTPaymentModule.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

contract SBTPaymentModule is ISBTPaymentModule, BaseSubscriptionModule, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private constant SBT_PAYMENT_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.sbt.payment.module.storage");

    struct SBTPaymentModuleStorage {
        EnumerableSet.AddressSet supportedSBTs;
        mapping(address => uint64) sbtToSubscriptionTime;
    }

    modifier onlySupportedSBT(address token_) {
        _onlySupportedSBT(token_);
        _;
    }

    function _getSBTPaymentModuleStorage()
        private
        pure
        returns (SBTPaymentModuleStorage storage _sbpms)
    {
        bytes32 slot_ = SBT_PAYMENT_MODULE_STORAGE_SLOT;

        assembly {
            _sbpms.slot := slot_
        }
    }

    function __SBTPaymentModule_init(
        SBTPaymentModuleInitData calldata initData_
    ) public onlyInitializing {
        for (uint256 i = 0; i < initData_.sbtEntries.length; ++i) {
            _updateSBT(
                initData_.sbtEntries[i].sbt,
                initData_.sbtEntries[i].subscriptionDurationPerToken
            );
        }
    }

    /// @inheritdoc ISBTPaymentModule
    function buySubscriptionWithSBT(
        address account_,
        address sbt_,
        uint256 tokenId_
    ) public virtual onlySupportedSBT(sbt_) {
        _buySubscriptionWithSBT(account_, sbt_, msg.sender, tokenId_);
    }

    /// @inheritdoc ISBTPaymentModule
    function getSupportedSBTs() public view returns (address[] memory) {
        return _getSBTPaymentModuleStorage().supportedSBTs.values();
    }

    /// @inheritdoc ISBTPaymentModule
    function isSupportedSBT(address sbtToken_) public view virtual returns (bool) {
        return _getSBTPaymentModuleStorage().supportedSBTs.contains(sbtToken_);
    }

    /// @inheritdoc ISBTPaymentModule
    function getSubscriptionDurationPerSBT(
        address sbtToken_
    ) public view virtual returns (uint64) {
        return _getSBTPaymentModuleStorage().sbtToSubscriptionTime[sbtToken_];
    }

    function _updateSBT(address sbt_, uint64 newDurationPerToken_) internal virtual {
        if (!isSupportedSBT(sbt_)) {
            _addSBT(sbt_);
        }

        _setSubscriptionDurationPerSBT(sbt_, newDurationPerToken_);
    }

    function _addSBT(address sbt_) internal virtual {
        _checkAddress(sbt_, "SBT");

        require(_getSBTPaymentModuleStorage().supportedSBTs.add(sbt_), SBTAlreadyAdded(sbt_));

        emit SBTAdded(sbt_);
    }

    function _removeSBT(address sbt_) internal virtual {
        SBTPaymentModuleStorage storage $ = _getSBTPaymentModuleStorage();

        _onlySupportedSBT(sbt_);

        $.supportedSBTs.remove(sbt_);
        delete $.sbtToSubscriptionTime[sbt_];

        emit SBTRemoved(sbt_);
    }

    function _setSubscriptionDurationPerSBT(
        address sbtToken_,
        uint64 newDurationPerToken_
    ) internal virtual {
        _getSBTPaymentModuleStorage().sbtToSubscriptionTime[sbtToken_] = newDurationPerToken_;

        emit SubscriptionDurationPerSBTUpdated(sbtToken_, newDurationPerToken_);
    }

    function _buySubscriptionWithSBT(
        address account_,
        address sbt_,
        address sbtOwner_,
        uint256 tokenId_
    ) internal virtual {
        _processSBTPayment(sbtOwner_, sbt_, tokenId_);

        _extendSubscription(account_, getSubscriptionDurationPerSBT(sbt_));

        emit SubscriptionBoughtWithSBT(sbt_, sbtOwner_, tokenId_);
    }

    function _processSBTPayment(
        address tokenOwner_,
        address sbt_,
        uint256 tokenId_
    ) internal virtual {
        IBurnableSBT burnableSBT_ = IBurnableSBT(sbt_);

        require(
            burnableSBT_.ownerOf(tokenId_) == tokenOwner_,
            NotASBTOwner(sbt_, tokenOwner_, tokenId_)
        );

        burnableSBT_.burn(tokenId_);
    }

    function _onlySupportedSBT(address sbt_) internal view {
        require(isSupportedSBT(sbt_), NotSupportedSBT(sbt_));
    }
}
