// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseSubscriptionManager} from "./BaseSubscriptionManager.sol";

import {VaultNameSubscriptionModule} from "./modules/VaultNameSubscriptionModule.sol";
import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {SBTSubscriptionModule} from "./modules/SBTSubscriptionModule.sol";

contract VaultSubscriptionManager is
    BaseSubscriptionManager,
    VaultNameSubscriptionModule,
    SignatureSubscriptionModule,
    SBTSubscriptionModule
{
    function initialize(
        address recoveryManager_,
        uint64 basePeriodDuration_,
        uint64 vaultNameRetentionPeriod_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata basePaymentTokenEntries_,
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __BaseSubscriptionManager_init(
            recoveryManager_,
            basePeriodDuration_,
            basePaymentTokenEntries_
        );

        __VaultNameSubscriptionModule_init(vaultNameRetentionPeriod_, vaultPaymentTokenEntries_);

        __SignatureSubscriptionModule_init(subscriptionSigner_);

        __SBTSubscriptionModule_init(sbtTokenEntries_);
    }

    function secondStepInitialize(address vaultFactoryAddr_) external onlyOwner reinitializer(2) {
        _secondStepInitialize(vaultFactoryAddr_);
    }

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external onlyOwner {
        _updateSBTTokens(sbtTokenEntries_);
    }

    function setSubscriptionSigner(address newSubscriptionSigner_) external onlyOwner {
        _setSubscriptionSigner(newSubscriptionSigner_);
    }

    function setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) external onlyOwner {
        _setVaultNameRetentionPeriod(newVaultNameRetentionPeriod_);
    }

    function updateVaultPaymentTokens(
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_
    ) external onlyOwner {
        _updateVaultPaymentTokens(vaultPaymentTokenEntries_);
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
    ) external onlyVault(account_) onlySupportedSBT(sbtTokenAddr_) {
        _buySubscriptionWithSBT(account_, sbtTokenAddr_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external onlyVault(account_) {
        _buySubscriptionWithSignature(account_, duration_, signature_);
    }

    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable onlyAvailableForPayment(token_) onlyVault(account_) nonReentrant {
        _updateVaultName(account_, token_, vaultName_, signature_);
    }

    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_
    ) external payable onlyAvailableForPayment(token_) onlyVault(account_) nonReentrant {
        _updateVaultName(account_, token_, vaultName_);
    }
}
