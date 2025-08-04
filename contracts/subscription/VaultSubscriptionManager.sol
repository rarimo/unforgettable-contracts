// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VaultNameSubscriptionModule} from "./modules/VaultNameSubscriptionModule.sol";
import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {SBTSubscriptionModule} from "./modules/SBTSubscriptionModule.sol";

contract VaultSubscriptionManager is
    VaultNameSubscriptionModule,
    SignatureSubscriptionModule,
    SBTSubscriptionModule
{
    function initialize(
        uint64 basePeriodDuration_,
        uint64 vaultNameRetentionPeriod_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata basePaymentTokenEntries_,
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __BaseSubscriptionManager_init(basePeriodDuration_, basePaymentTokenEntries_);

        __VaultNameSubscriptionModule_init(vaultNameRetentionPeriod_, vaultPaymentTokenEntries_);

        __SignatureSubscriptionModule_init(subscriptionSigner_);

        __SBTSubscriptionModule_init(sbtTokenEntries_);
    }

    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    ) external payable override onlyVault(account_) onlyAvailableForPayment(token_) nonReentrant {
        _buySubscription(account_, token_, duration_);
    }

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external override onlyVault(account_) onlySupportedSBT(sbtTokenAddr_) {
        _buySubscriptionWithSBT(account_, sbtTokenAddr_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external override onlyVault(account_) {
        _buySubscriptionWithSignature(account_, duration_, signature_);
    }
}
