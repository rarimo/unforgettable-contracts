// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseSubscriptionManager} from "./BaseSubscriptionManager.sol";

import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {SBTSubscriptionModule} from "./modules/SBTSubscriptionModule.sol";

contract AccountSubscriptionManager is
    BaseSubscriptionManager,
    SignatureSubscriptionModule,
    SBTSubscriptionModule
{
    function initialize(
        address recoveryManager_,
        uint64 basePeriodDuration_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __BaseSubscriptionManager_init(
            recoveryManager_,
            basePeriodDuration_,
            paymentTokenEntries_
        );

        __SignatureSubscriptionModule_init(subscriptionSigner_);

        __SBTSubscriptionModule_init(sbtTokenEntries_);
    }

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external onlyOwner {
        _updateSBTTokens(sbtTokenEntries_);
    }

    function setSubscriptionSigner(address newSubscriptionSigner_) external onlyOwner {
        _setSubscriptionSigner(newSubscriptionSigner_);
    }

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external onlySupportedSBT(sbtTokenAddr_) {
        _buySubscriptionWithSBT(account_, sbtTokenAddr_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external {
        _buySubscriptionWithSignature(account_, duration_, signature_);
    }
}
