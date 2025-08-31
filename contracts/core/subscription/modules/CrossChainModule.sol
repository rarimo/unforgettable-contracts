// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ICrossChainModule} from "../../../interfaces/core/subscription/ICrossChainModule.sol";
import {ISubscriptionsSynchronizer} from "../../../interfaces/crosschain/ISubscriptionsSynchronizer.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

contract CrossChainModule is ICrossChainModule, BaseSubscriptionModule, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 private constant CROSS_CHAIN_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.cross.chain.module.storage");

    event SubscriptionSynchronizerUpdated(address indexed subscriptionSynchronizer);

    struct CrossChainModuleStorage {
        ISubscriptionsSynchronizer subscriptionsSynchronizer;
    }

    function _getCrossChainModuleStorage()
        private
        pure
        returns (CrossChainModuleStorage storage _ccms)
    {
        bytes32 slot_ = CROSS_CHAIN_MODULE_STORAGE_SLOT;

        assembly {
            _ccms.slot := slot_
        }
    }

    function __CrossChainModule_init(
        CrossChainModuleInitData calldata initData_
    ) public onlyInitializing {
        _setSubscriptionSynchronizer(initData_.subscriptionsSynchronizer);
    }

    function _setSubscriptionSynchronizer(address subscriptionSynchronizer_) internal {
        _checkAddress(subscriptionSynchronizer_, "SubscriptionSynchronizer");

        _getCrossChainModuleStorage().subscriptionsSynchronizer = ISubscriptionsSynchronizer(
            subscriptionSynchronizer_
        );
    }

    function _extendSubscription(
        address account_,
        uint64 duration_
    ) internal virtual override(BaseSubscriptionModule) {
        super._extendSubscription(account_, duration_);

        uint64 _subscriptionStartTime = getSubscriptionStartTime(account_);
        uint64 _subscriptionEndTime = getSubscriptionEndTime(account_);
        bool _isNewSubscription = _subscriptionStartTime == uint64(block.timestamp);

        _getCrossChainModuleStorage().subscriptionsSynchronizer.saveSubscriptionData(
            account_,
            _subscriptionStartTime,
            _subscriptionEndTime,
            _isNewSubscription
        );
    }
}
