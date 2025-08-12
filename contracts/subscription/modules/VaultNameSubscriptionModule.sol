// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

import {IVault} from "../../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../../interfaces/vaults/IVaultFactory.sol";
import {IVaultNameSubscriptionModule} from "../../interfaces/subscription/modules/IVaultNameSubscriptionModule.sol";

import {TokensHelper} from "../../libs/TokensHelper.sol";
import {EIP712SignatureChecker} from "../../libs/EIP712SignatureChecker.sol";

abstract contract VaultNameSubscriptionModule is
    IVaultNameSubscriptionModule,
    BaseSubscriptionModule,
    NoncesUpgradeable,
    EIP712Upgradeable
{
    using TokensHelper for address;
    using EIP712SignatureChecker for address;

    bytes32 public constant UPDATE_VAULT_NAME_TYPEHASH =
        keccak256("UpdateVaultName(address account,string vaultName,uint256 nonce)");

    bytes32 public constant VAULT_NAME_SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.name.subscription.module.storage");

    uint256 public constant MIN_VAULT_NAME_LENGTH = 3;

    struct VaultNameSubscriptionModuleStorage {
        IVaultFactory vaultFactory;
        uint64 vaultNameRetentionPeriod;
        mapping(address => uint256) baseVaultNameCosts;
        // Vault names
        mapping(address => string) vaultNames;
        mapping(bytes32 => address) namesToVaults;
    }

    modifier onlyVault(address account_) {
        _onlyVault(account_);
        _;
    }

    function _getVaultNameSubscriptionModuleStorage()
        private
        pure
        returns (VaultNameSubscriptionModuleStorage storage _vnsms)
    {
        bytes32 slot_ = VAULT_NAME_SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly {
            _vnsms.slot := slot_
        }
    }

    function __VaultNameSubscriptionModule_init(
        uint64 vaultNameRetentionPeriod_,
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_
    ) public onlyInitializing {
        __EIP712_init("VaultNameSubscriptionModule", "v1.0.0");

        _setVaultNameRetentionPeriod(vaultNameRetentionPeriod_);

        _updateVaultPaymentTokens(vaultPaymentTokenEntries_);
    }

    function getVaultNameRetentionPeriod() external view returns (uint64) {
        return _getVaultNameSubscriptionModuleStorage().vaultNameRetentionPeriod;
    }

    function getVaultFactory() external view returns (address) {
        return address(_getVaultNameSubscriptionModuleStorage().vaultFactory);
    }

    function getTokenBaseVaultNameCost(address token_) public view returns (uint256) {
        return _getVaultNameSubscriptionModuleStorage().baseVaultNameCosts[token_];
    }

    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) public view returns (uint256) {
        uint256 baseVaultNameCostInTokens_ = getTokenBaseVaultNameCost(token_);
        uint256 factor_ = _getVaultNameCostMultiplier(vaultName_);

        return Math.mulDiv(baseVaultNameCostInTokens_, factor_, PERCENTAGE_100);
    }

    function getVaultName(address account_) public view returns (string memory) {
        return _getVaultNameSubscriptionModuleStorage().vaultNames[account_];
    }

    function getVault(string memory vaultName_) public view returns (address) {
        return
            _getVaultNameSubscriptionModuleStorage().namesToVaults[keccak256(bytes(vaultName_))];
    }

    function hashUpdateVaultName(
        address account_,
        string memory vaultName_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        UPDATE_VAULT_NAME_TYPEHASH,
                        account_,
                        keccak256(bytes(vaultName_)),
                        nonce_
                    )
                )
            );
    }

    function isVaultNameAvailable(string memory name_) public view returns (bool) {
        address previousVault_ = getVault(name_);

        if (previousVault_ == address(0)) {
            return true;
        }

        uint64 subscriptionEndTime_ = getAccountSubscriptionEndTime(previousVault_);

        bool retentionPeriodPassed_ = subscriptionEndTime_ +
            _getVaultNameSubscriptionModuleStorage().vaultNameRetentionPeriod <
            block.timestamp;

        return hasSubscriptionDebt(previousVault_) && retentionPeriodPassed_;
    }

    function _secondStepInitialize(address vaultFactoryAddr_) internal {
        _getVaultNameSubscriptionModuleStorage().vaultFactory = IVaultFactory(vaultFactoryAddr_);
    }

    function _setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) internal {
        _getVaultNameSubscriptionModuleStorage()
            .vaultNameRetentionPeriod = newVaultNameRetentionPeriod_;

        emit VaultNameRetentionPeriodUpdated(newVaultNameRetentionPeriod_);
    }

    function _updateVaultPaymentTokens(
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_
    ) internal {
        VaultNameSubscriptionModuleStorage storage $ = _getVaultNameSubscriptionModuleStorage();

        for (uint256 i = 0; i < vaultPaymentTokenEntries_.length; ++i) {
            VaultPaymentTokenUpdateEntry calldata currentEntry_ = vaultPaymentTokenEntries_[i];

            _checkAddress(currentEntry_.paymentToken);

            $.baseVaultNameCosts[currentEntry_.paymentToken] = currentEntry_.baseVaultNameCost;

            emit VaultPaymentTokenUpdated(
                currentEntry_.paymentToken,
                currentEntry_.baseVaultNameCost
            );
        }
    }

    function _updateVaultName(
        address account_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) internal {
        uint256 currentNonce_ = _useNonce(account_);
        bytes32 updateVaultNameHash_ = hashUpdateVaultName(account_, vaultName_, currentNonce_);

        address vaultOwner_ = IVault(account_).owner();
        vaultOwner_.checkSignature(updateVaultNameHash_, signature_);

        _updateVaultNameInternal(account_, token_, vaultOwner_, vaultName_);
    }

    function _updateVaultName(
        address account_,
        address token_,
        string memory vaultName_
    ) internal {
        require(
            address(_getVaultNameSubscriptionModuleStorage().vaultFactory) == msg.sender,
            NotAVaultFactory(msg.sender)
        );

        _updateVaultNameInternal(account_, token_, msg.sender, vaultName_);
    }

    function _updateVaultNameInternal(
        address account_,
        address token_,
        address payer_,
        string memory vaultName_
    ) internal {
        _validateVaultName(vaultName_, account_);

        uint256 vaultNameCost_ = getVaultNameCost(token_, vaultName_);
        token_.receiveTokens(payer_, vaultNameCost_);

        VaultNameSubscriptionModuleStorage storage $ = _getVaultNameSubscriptionModuleStorage();

        address previousVault_ = getVault(vaultName_);

        if (previousVault_ != address(0)) {
            delete $.vaultNames[previousVault_];

            emit VaultNameReassigned(vaultName_, previousVault_, account_);
        }

        $.vaultNames[account_] = vaultName_;
        $.namesToVaults[keccak256(bytes(vaultName_))] = account_;

        emit VaultNameUpdated(account_, vaultName_);
    }

    function _validateVaultName(string memory vaultName_, address account_) internal view {
        require(bytes(vaultName_).length >= MIN_VAULT_NAME_LENGTH, VaultNameTooShort(vaultName_));

        string memory currentName_ = getVaultName(account_);

        require(
            keccak256(bytes(currentName_)) != keccak256(bytes(vaultName_)),
            VaultNameUnchanged(vaultName_)
        );

        require(hasActiveSubscription(account_), InactiveVaultSubscription(account_));

        require(isVaultNameAvailable(vaultName_), VaultNameAlreadyTaken(vaultName_));
    }

    function _onlyVault(address account_) internal view {
        require(
            _getVaultNameSubscriptionModuleStorage().vaultFactory.isVault(account_),
            NotAVault(account_)
        );
    }

    function _getVaultNameCostMultiplier(
        string memory vaultName_
    ) internal pure returns (uint256) {
        uint256 nameLength_ = bytes(vaultName_).length;

        if (nameLength_ >= 5) {
            return PERCENTAGE_100;
        }
        if (nameLength_ == 4) {
            return PERCENTAGE_100 * 5;
        }

        return PERCENTAGE_100 * 50;
    }
}
