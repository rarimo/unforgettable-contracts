// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";
import {ITokensPaymentModule} from "../interfaces/core/subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "../interfaces/core/subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "../interfaces/core/subscription/ISignatureSubscriptionModule.sol";

import {BaseSubscriptionManager} from "../core/subscription/BaseSubscriptionManager.sol";

contract VaultSubscriptionManager is
    IVaultSubscriptionManager,
    BaseSubscriptionManager,
    ADeployerGuard
{
    bytes32 private constant VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.subscription.manager.storage");

    struct VaultSubscriptionManagerStorage {
        IVaultFactory vaultFactory;
    }

    modifier onlyVaultFactory() {
        _onlyVaultFactory();
        _;
    }

    modifier onlyVault(address account_) {
        _onlyVault(account_);
        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getVaultSubscriptionManagerStorage()
        private
        pure
        returns (VaultSubscriptionManagerStorage storage _vsms)
    {
        bytes32 slot_ = VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _vsms.slot := slot_
        }
    }

    function initialize(
        VaultSubscriptionManagerInitData calldata initData_
    ) external initializer onlyDeployer {
        __BaseSubscriptionManager_init(
            initData_.subscriptionCreators,
            initData_.tokensPaymentInitData,
            initData_.sbtPaymentInitData,
            initData_.sigSubscriptionInitData,
            initData_.crossChainInitData
        );

        _setVaultFactory(initData_.vaultFactoryAddr);
    }

    function buySubscription(
        address vault_,
        address token_,
        uint64 duration_
    ) public payable override(BaseSubscriptionManager, ITokensPaymentModule) onlyVault(vault_) {
        super.buySubscription(vault_, token_, duration_);
    }

    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        uint256 tokenId_
    ) public override(BaseSubscriptionManager, ISBTPaymentModule) onlyVault(vault_) {
        super.buySubscriptionWithSBT(vault_, sbt_, tokenId_);
    }

    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        address sbtOwner_,
        uint256 tokenId_
    ) public onlySupportedSBT(sbt_) onlyVault(vault_) onlyVaultFactory nonReentrant whenNotPaused {
        _buySubscriptionWithSBT(vault_, sbt_, sbtOwner_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) public override(BaseSubscriptionManager, ISignatureSubscriptionModule) onlyVault(vault_) {
        super.buySubscriptionWithSignature(vault_, duration_, signature_);
    }

    function buySubscriptionWithSignature(
        address sender_,
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) public onlyVault(vault_) onlyVaultFactory nonReentrant whenNotPaused {
        _buySubscriptionWithSignature(sender_, vault_, duration_, signature_);
    }

    function getVaultFactory() public view returns (address) {
        return address(_getVaultSubscriptionManagerStorage().vaultFactory);
    }

    function _setVaultFactory(address vaultFactory_) internal {
        _checkAddress(vaultFactory_, "VaultFactory");

        _getVaultSubscriptionManagerStorage().vaultFactory = IVaultFactory(vaultFactory_);

        emit VaultFactoryUpdated(vaultFactory_);
    }

    function _onlyVault(address vault_) internal view {
        require(
            _getVaultSubscriptionManagerStorage().vaultFactory.isVault(vault_),
            NotAVault(vault_)
        );
    }

    function _onlyVaultFactory() internal view {
        require(msg.sender == getVaultFactory(), NotAVaultFactory(msg.sender));
    }
}
