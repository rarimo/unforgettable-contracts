// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";
import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";
import {ITokensPaymentModule} from "../interfaces/core/subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "../interfaces/core/subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "../interfaces/core/subscription/ISignatureSubscriptionModule.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";
import {EIP712SignatureChecker} from "../libs/EIP712SignatureChecker.sol";

import {BaseSubscriptionManager} from "../core/subscription/BaseSubscriptionManager.sol";

contract VaultSubscriptionManager is
    IVaultSubscriptionManager,
    BaseSubscriptionManager,
    ADeployerGuard
{
    using TokensHelper for address;
    using EIP712SignatureChecker for address;

    bytes32 public constant UPDATE_VAULT_NAME_TYPEHASH =
        keccak256("UpdateVaultName(address account,string vaultName,uint256 nonce)");

    bytes32 private constant VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.subscription.manager.storage");

    uint256 public constant MIN_VAULT_NAME_LENGTH = 3;

    struct VaultSubscriptionManagerStorage {
        IVaultFactory vaultFactory;
        uint64 vaultNameRetentionPeriod;
        mapping(address => uint256) baseVaultNameCosts;
        // Vault names
        mapping(address => string) vaultNames;
        mapping(bytes32 => address) namesToVaults;
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
        _setVaultNameRetentionPeriod(initData_.vaultNameRetentionPeriod);

        for (uint256 i = 0; i < initData_.vaultPaymentTokenEntries.length; ++i) {
            VaultPaymentTokenUpdateEntry calldata current_ = initData_.vaultPaymentTokenEntries[i];

            _setBaseVaultNameCost(current_.paymentToken, current_.baseVaultNameCost);
        }
    }

    function setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) external onlyOwner {
        _setVaultNameRetentionPeriod(newVaultNameRetentionPeriod_);
    }

    function updateVaultPaymentTokens(
        VaultPaymentTokenUpdateEntry[] calldata vaultPaymentTokenEntries_
    ) external onlyOwner {
        for (uint256 i = 0; i < vaultPaymentTokenEntries_.length; ++i) {
            VaultPaymentTokenUpdateEntry calldata current_ = vaultPaymentTokenEntries_[i];

            _setBaseVaultNameCost(current_.paymentToken, current_.baseVaultNameCost);
        }
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

    function buySubscriptionWithSignature(
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) public override(BaseSubscriptionManager, ISignatureSubscriptionModule) onlyVault(vault_) {
        super.buySubscriptionWithSignature(vault_, duration_, signature_);
    }

    function updateVaultName(
        address vault_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable onlySupportedToken(token_) onlyVault(vault_) nonReentrant {
        bytes32 updateVaultNameHash_ = hashUpdateVaultName(vault_, vaultName_, _useNonce(vault_));

        address vaultOwner_ = IVault(vault_).owner();
        vaultOwner_.checkSignature(updateVaultNameHash_, signature_);

        _updateVaultName(vault_, token_, vaultOwner_, vaultName_);
    }

    function updateVaultName(
        address vault_,
        address token_,
        string memory vaultName_
    ) external payable onlySupportedToken(token_) onlyVault(vault_) onlyVaultFactory nonReentrant {
        _updateVaultName(vault_, token_, msg.sender, vaultName_);
    }

    function getVaultFactory() public view returns (address) {
        return address(_getVaultSubscriptionManagerStorage().vaultFactory);
    }

    function getVaultNameRetentionPeriod() public view returns (uint64) {
        return _getVaultSubscriptionManagerStorage().vaultNameRetentionPeriod;
    }

    function getVaultName(address vault_) public view returns (string memory) {
        return _getVaultSubscriptionManagerStorage().vaultNames[vault_];
    }

    function getVaultByName(string memory vaultName_) public view returns (address) {
        return _getVaultSubscriptionManagerStorage().namesToVaults[keccak256(bytes(vaultName_))];
    }

    function getTokenBaseVaultNameCost(address paymentToken_) public view returns (uint256) {
        return _getVaultSubscriptionManagerStorage().baseVaultNameCosts[paymentToken_];
    }

    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) public view returns (uint256) {
        uint256 baseVaultNameCostInTokens_ = getTokenBaseVaultNameCost(token_);
        uint256 factor_ = _getVaultNameCostMultiplier(vaultName_);

        return Math.mulDiv(baseVaultNameCostInTokens_, factor_, PERCENTAGE_100);
    }

    function isVaultNameAvailable(string memory name_) public view returns (bool) {
        address previousVault_ = getVaultByName(name_);

        if (previousVault_ == address(0)) {
            return true;
        }

        uint64 subscriptionEndTime_ = getSubscriptionEndTime(previousVault_);

        bool retentionPeriodPassed_ = subscriptionEndTime_ + getVaultNameRetentionPeriod() <
            block.timestamp;

        return hasSubscriptionDebt(previousVault_) && retentionPeriodPassed_;
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

    function _setVaultFactory(address vaultFactory_) internal {
        _checkAddress(vaultFactory_, "VaultFactory");

        _getVaultSubscriptionManagerStorage().vaultFactory = IVaultFactory(vaultFactory_);

        emit VaultFactoryUpdated(vaultFactory_);
    }

    function _setVaultNameRetentionPeriod(uint64 newVaultNameRetentionPeriod_) internal {
        _getVaultSubscriptionManagerStorage()
            .vaultNameRetentionPeriod = newVaultNameRetentionPeriod_;

        emit VaultNameRetentionPeriodUpdated(newVaultNameRetentionPeriod_);
    }

    function _setBaseVaultNameCost(address paymentToken_, uint256 baseVaultNameCost_) internal {
        _checkAddress(paymentToken_, "PaymentToken");

        _getVaultSubscriptionManagerStorage().baseVaultNameCosts[
            paymentToken_
        ] = baseVaultNameCost_;

        emit VaultNameCostUpdated(paymentToken_, baseVaultNameCost_);
    }

    function _updateVaultName(
        address vault_,
        address token_,
        address payer_,
        string memory vaultName_
    ) internal {
        _validateVaultName(vaultName_, vault_);

        uint256 vaultNameCost_ = getVaultNameCost(token_, vaultName_);
        token_.receiveTokens(payer_, vaultNameCost_);

        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        address previousVault_ = getVaultByName(vaultName_);

        if (previousVault_ != address(0)) {
            delete $.vaultNames[previousVault_];

            emit VaultNameReassigned(vaultName_, previousVault_, vault_);
        }

        $.vaultNames[vault_] = vaultName_;
        $.namesToVaults[keccak256(bytes(vaultName_))] = vault_;

        emit VaultNameUpdated(vault_, vaultName_);
    }

    function _validateVaultName(string memory vaultName_, address vault_) internal view {
        require(bytes(vaultName_).length >= MIN_VAULT_NAME_LENGTH, VaultNameTooShort(vaultName_));

        string memory currentName_ = getVaultName(vault_);

        require(
            keccak256(bytes(currentName_)) != keccak256(bytes(vaultName_)),
            VaultNameUnchanged(vaultName_)
        );

        require(hasActiveSubscription(vault_), InactiveVaultSubscription(vault_));
        require(isVaultNameAvailable(vaultName_), VaultNameAlreadyTaken(vaultName_));
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
