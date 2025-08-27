// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ICrossChainModule} from "../../../interfaces/core/subscription/ICrossChainModule.sol";
import {ISubscriptionSynchronizer} from "../../../interfaces/crosschain/ISubscriptionSynchronizer.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

contract CrossChainModule is ICrossChainModule, BaseSubscriptionModule, Initializable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 private constant CROSS_CHAIN_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.cross.chain.module.storage");

    struct CrossChainModuleStorage {
        ISubscriptionSynchronizer subscriptionSynchronizer;
        EnumerableSet.UintSet targetChains;
    }

    event TargetChainAdded(uint16 targetChain);

    error ChainNotSupported(uint16 chainId);

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
        _updateSubscriptionSynchronizer(initData_.subscriptionSynchronizer);

        for (uint256 i = 0; i < initData_.targetChains.length; ++i) {
            _addTargetChain(initData_.targetChains[i]);
        }
    }

    function syncSubscriptionState(uint16 targetChain_) public {
        _syncSubscriptionState(targetChain_);
    }

    function isChainSupported(uint16 targetChain_) public view returns (bool) {
        return _getCrossChainModuleStorage().targetChains.contains(targetChain_);
    }

    function supportedChains() public view returns (uint256[] memory) {
        return _getCrossChainModuleStorage().targetChains.values();
    }

    function _syncSubscriptionState(uint16 targetChain_) internal {
        require(isChainSupported(targetChain_), ChainNotSupported(targetChain_));

        _getCrossChainModuleStorage().subscriptionSynchronizer.sync(targetChain_);
    }

    function _updateSubscriptionSynchronizer(address subscriptionSynchronizer_) internal {
        _checkAddress(subscriptionSynchronizer_, "SubscriptionSynchronizer");

        _getCrossChainModuleStorage().subscriptionSynchronizer = ISubscriptionSynchronizer(
            subscriptionSynchronizer_
        );
    }

    function _addTargetChain(uint16 targetChain_) internal {
        _getCrossChainModuleStorage().targetChains.add(targetChain_);
    }
}
