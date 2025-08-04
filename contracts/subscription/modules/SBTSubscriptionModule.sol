// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBurnableSBT} from "../../interfaces/tokens/IBurnableSBT.sol";
import {ISBTSubscriptionModule} from "../../interfaces/subscription/modules/ISBTSubscriptionModule.sol";

import {BaseSubscriptionManager} from "../BaseSubscriptionManager.sol";

contract SBTSubscriptionModule is ISBTSubscriptionModule, BaseSubscriptionManager {
    bytes32 public constant SBT_SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.sbt.subscription.module.storage");

    struct SBTSubscriptionModuleStorage {
        mapping(address => uint64) sbtToSubscriptionTime;
    }

    modifier onlySupportedSBT(address token_) {
        _onlySupportedSBT(token_);
        _;
    }

    function _getSBTSubscriptionModuleStorage()
        private
        pure
        returns (SBTSubscriptionModuleStorage storage _sbsms)
    {
        bytes32 slot_ = SBT_SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly {
            _sbsms.slot := slot_
        }
    }

    function __SBTSubscriptionModule_init(
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) public onlyInitializing {
        _updateSBTTokens(sbtTokenEntries_);
    }

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external onlyOwner {
        _updateSBTTokens(sbtTokenEntries_);
    }

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external virtual onlySupportedSBT(sbtTokenAddr_) {
        _buySubscriptionWithSBT(account_, sbtTokenAddr_, tokenId_);
    }

    function isSupportedSBT(address sbtToken_) public view returns (bool) {
        return _getSBTSubscriptionModuleStorage().sbtToSubscriptionTime[sbtToken_] > 0;
    }

    function getSubscriptionTimePerSBT(address sbtToken_) public view returns (uint64) {
        return _getSBTSubscriptionModuleStorage().sbtToSubscriptionTime[sbtToken_];
    }

    function _updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) internal {
        SBTSubscriptionModuleStorage storage $ = _getSBTSubscriptionModuleStorage();

        for (uint256 i = 0; i < sbtTokenEntries_.length; ++i) {
            SBTTokenUpdateEntry calldata currentEntry_ = sbtTokenEntries_[i];

            $.sbtToSubscriptionTime[currentEntry_.sbtToken] = currentEntry_
                .subscriptionTimePerToken;

            emit SBTTokenUpdated(currentEntry_.sbtToken, currentEntry_.subscriptionTimePerToken);
        }
    }

    function _buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) internal {
        IBurnableSBT sbtToken_ = IBurnableSBT(sbtTokenAddr_);

        require(
            sbtToken_.ownerOf(tokenId_) == msg.sender,
            NotATokenOwner(sbtTokenAddr_, msg.sender, tokenId_)
        );

        sbtToken_.burn(tokenId_);

        _extendSubscription(account_, getSubscriptionTimePerSBT(sbtTokenAddr_));

        emit SubscriptionBoughtWithSBT(sbtTokenAddr_, msg.sender, tokenId_);
    }

    function _onlySupportedSBT(address token_) internal view {
        require(isSupportedSBT(token_), NotSupportedSBT(token_));
    }
}
