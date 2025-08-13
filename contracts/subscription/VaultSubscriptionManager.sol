// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {IVaultSubscriptionManager} from "../interfaces/subscription/IVaultSubscriptionManager.sol";

import {BaseSubscriptionManager} from "./BaseSubscriptionManager.sol";

import {VaultNameSubscriptionModule} from "./modules/VaultNameSubscriptionModule.sol";
import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {SBTSubscriptionModule} from "./modules/SBTSubscriptionModule.sol";

contract VaultSubscriptionManager is
    ADeployerGuard,
    BaseSubscriptionManager,
    VaultNameSubscriptionModule,
    SignatureSubscriptionModule,
    SBTSubscriptionModule
{
    struct VaultSubscriptionManagerInitData {
        address recoveryManager;
        address vaultFactoryAddr;
        address subscriptionSigner;
        uint64 basePeriodDuration;
        uint64 vaultNameRetentionPeriod;
        PaymentTokenUpdateEntry[] basePaymentTokenEntries;
        VaultPaymentTokenUpdateEntry[] vaultPaymentTokenEntries;
        SBTTokenUpdateEntry[] sbtTokenEntries;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        VaultSubscriptionManagerInitData calldata initData
    ) external initializer onlyDeployer {
        __BaseSubscriptionManager_init(
            initData.recoveryManager,
            initData.basePeriodDuration,
            initData.basePaymentTokenEntries
        );

        __VaultNameSubscriptionModule_init(
            initData.vaultFactoryAddr,
            initData.vaultNameRetentionPeriod,
            initData.vaultPaymentTokenEntries
        );
        __SignatureSubscriptionModule_init(initData.subscriptionSigner);
        __SBTSubscriptionModule_init(initData.sbtTokenEntries);
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
