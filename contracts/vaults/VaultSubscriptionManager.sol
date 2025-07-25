// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IBurnableSBT} from "../interfaces/tokens/IBurnableSBT.sol";
import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";
import {EIP712SignatureChecker} from "../libs/EIP712SignatureChecker.sol";

contract VaultSubscriptionManager is
    IVaultSubscriptionManager,
    OwnableUpgradeable,
    NoncesUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for *;
    using TokensHelper for address;
    using EIP712SignatureChecker for address;

    bytes32 public constant BUY_SUBSCRIPTION_TYPEHASH =
        keccak256("BuySubscription(address sender,uint64 duration,uint256 nonce)");

    bytes32 public constant UPDATE_VAULT_NAME_TYPEHASH =
        keccak256("UpdateVaultName(address account,string vaultName,uint256 nonce)");

    bytes32 public constant VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.subscription.manager.storage");

    uint256 public constant MIN_VAULT_NAME_LENGTH = 3;

    struct VaultSubscriptionManagerStorage {
        IVaultFactory vaultFactory;
        uint64 basePeriodDuration;
        uint192 vaultNameRetentionPeriod;
        address subscriptionSigner;
        // TokensSettings
        EnumerableSet.AddressSet paymentTokens;
        mapping(address => PaymentTokenSettings) paymentTokensSettings;
        mapping(address => uint64) sbtToSubscriptionTime;
        // Subscription duration factors
        mapping(uint64 => uint256) subscriptionDurationFactors;
        // Accounts subscription data
        mapping(address => AccountSubscriptionData) accountsSubscriptionData;
        // Vault names
        mapping(address => string) vaultNames;
        mapping(bytes32 => address) namesToVaults;
    }

    modifier onlyVault(address account_) {
        _onlyVault(account_);
        _;
    }

    modifier onlyAvailableForPayment(address token_) {
        _onlyAvailableForPayment(token_);
        _;
    }

    modifier onlySupportedSBT(address token_) {
        _onlySupportedSBT(token_);
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function _getVaultSubscriptionManagerStorage()
        private
        pure
        returns (VaultSubscriptionManagerStorage storage _vsms)
    {
        bytes32 slot_ = VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly {
            _vsms.slot := slot_
        }
    }

    function initialize(
        uint64 basePeriodDuration_,
        uint192 vaultNameRetentionPeriod_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __Ownable_init(msg.sender);
        __EIP712_init("VaultSubscriptionManager", "v1.0.0");
        __ReentrancyGuard_init();

        _setBasePeriodDuration(basePeriodDuration_);
        _setSubscriptionSigner(subscriptionSigner_);
        _setVaultNameRetentionPeriod(vaultNameRetentionPeriod_);

        _updatePaymentTokens(paymentTokenEntries_);
        _updateSBTTokens(sbtTokenEntries_);
    }

    function secondStepInitialize(address vaultFactoryAddr_) external onlyOwner reinitializer(2) {
        _getVaultSubscriptionManagerStorage().vaultFactory = IVaultFactory(vaultFactoryAddr_);
    }

    function setSubscriptionSigner(address newSubscriptionSigner_) external onlyOwner {
        _setSubscriptionSigner(newSubscriptionSigner_);
    }

    function setVaultNameRetentionPeriod(uint192 newVaultNameRetentionPeriod_) external onlyOwner {
        _setVaultNameRetentionPeriod(newVaultNameRetentionPeriod_);
    }

    function updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) external onlyOwner {
        _updatePaymentTokens(paymentTokenEntries_);
    }

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external onlyOwner {
        _updateSBTTokens(sbtTokenEntries_);
    }

    function updateTokenPaymentStatus(address token_, bool newStatus_) external onlyOwner {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        require($.paymentTokens.contains(token_), TokenNotConfigured(token_));
        require(
            isAvailableForPayment(token_) != newStatus_,
            InvalidTokenPaymentStatus(token_, newStatus_)
        );

        $.paymentTokensSettings[token_].isAvailableForPayment = newStatus_;

        emit TokenPaymentStatusUpdated(token_, newStatus_);
    }

    function updateSubscriptionDurationFactor(
        uint64 duration_,
        uint256 factor_
    ) external onlyOwner {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        $.subscriptionDurationFactors[duration_] = factor_;

        emit SubscriptionDurationFactorUpdated(duration_, factor_);
    }

    function withdrawTokens(
        address tokenAddr_,
        address to_,
        uint256 amount_
    ) external onlyOwner nonReentrant {
        _checkAddress(to_);

        amount_ = tokenAddr_.sendTokens(to_, amount_);

        emit TokensWithdrawn(tokenAddr_, to_, amount_);
    }

    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    ) external payable onlyAvailableForPayment(token_) onlyVault(account_) nonReentrant {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        require(duration_ >= $.basePeriodDuration, InvalidSubscriptionDuration(duration_));

        uint256 totalCost_ = getSubscriptionCost(account_, token_, duration_);

        _updateAccountSubscriptionCost(account_, token_);

        token_.receiveTokens(msg.sender, totalCost_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithToken(token_, msg.sender, totalCost_);
    }

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external onlySupportedSBT(sbtTokenAddr_) onlyVault(account_) {
        IBurnableSBT sbtToken_ = IBurnableSBT(sbtTokenAddr_);

        require(
            sbtToken_.ownerOf(tokenId_) == msg.sender,
            NotATokenOwner(sbtTokenAddr_, msg.sender, tokenId_)
        );

        sbtToken_.burn(tokenId_);

        _extendSubscription(account_, getSubscriptionTimePerSBT(sbtTokenAddr_));

        emit SubscriptionBoughtWithSBT(sbtTokenAddr_, msg.sender, tokenId_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external onlyVault(account_) {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        uint256 currentNonce_ = _useNonce(msg.sender);
        bytes32 buySubscriptionHash_ = hashBuySubscription(msg.sender, duration_, currentNonce_);
        $.subscriptionSigner.checkSignature(buySubscriptionHash_, signature_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithSignature(msg.sender, duration_, currentNonce_);
    }

    function updateVaultName(
        address account_,
        address token_,
        string memory vaultName_,
        bytes memory signature_
    ) external payable onlyAvailableForPayment(token_) onlyVault(account_) nonReentrant {
        _validateVaultName(vaultName_, account_);

        uint256 currentNonce_ = _useNonce(account_);
        bytes32 updateVaultNameHash_ = hashUpdateVaultName(account_, vaultName_, currentNonce_);

        address vaultOwner_ = IVault(account_).owner();
        vaultOwner_.checkSignature(updateVaultNameHash_, signature_);

        uint256 vaultNameCost_ = getVaultNameCost(token_, vaultName_);

        token_.receiveTokens(vaultOwner_, vaultNameCost_);

        _updateVaultName(account_, vaultName_);
    }

    function getBasePeriodDuration() external view returns (uint64) {
        return _getVaultSubscriptionManagerStorage().basePeriodDuration;
    }

    function getSubscriptionSigner() external view returns (address) {
        return _getVaultSubscriptionManagerStorage().subscriptionSigner;
    }

    function getVaultNameRetentionPeriod() external view returns (uint192) {
        return _getVaultSubscriptionManagerStorage().vaultNameRetentionPeriod;
    }

    function getPaymentTokens() external view returns (address[] memory) {
        return _getVaultSubscriptionManagerStorage().paymentTokens.values();
    }

    function getPaymentTokensSettings(
        address token_
    ) external view returns (PaymentTokenSettings memory) {
        return _getVaultSubscriptionManagerStorage().paymentTokensSettings[token_];
    }

    function getVaultFactory() external view returns (address) {
        return address(_getVaultSubscriptionManagerStorage().vaultFactory);
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256) {
        return _getVaultSubscriptionManagerStorage().subscriptionDurationFactors[duration_];
    }

    function getTokenBaseSubscriptionCost(address token_) public view returns (uint256) {
        return
            _getVaultSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .baseSubscriptionCost;
    }

    function getTokenBaseVaultNameCost(address token_) public view returns (uint256) {
        return
            _getVaultSubscriptionManagerStorage().paymentTokensSettings[token_].baseVaultNameCost;
    }

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) public view returns (uint256) {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        uint256 accountSavedCost_ = $.accountsSubscriptionData[account_].accountSubscriptionCosts[
            token_
        ];
        uint256 currentCost_ = getTokenBaseSubscriptionCost(token_);

        return accountSavedCost_ > 0 ? Math.min(accountSavedCost_, currentCost_) : currentCost_;
    }

    function getSubscriptionCost(
        address account_,
        address token_,
        uint64 duration_
    ) public view returns (uint256 totalCost_) {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        require(duration_ > 0, ZeroDuration());
        require($.paymentTokens.contains(token_), TokenNotConfigured(token_));

        uint256 basePeriodDuration_ = $.basePeriodDuration;
        uint256 subscriptionCostInTokens_ = getBaseSubscriptionCostForAccount(account_, token_);

        uint256 wholePeriodsCount_ = duration_ / basePeriodDuration_;
        totalCost_ = subscriptionCostInTokens_ * wholePeriodsCount_;

        uint256 lastSeconds_ = duration_ % basePeriodDuration_;
        if (lastSeconds_ > 0) {
            totalCost_ += Math.mulDiv(
                subscriptionCostInTokens_,
                lastSeconds_,
                basePeriodDuration_
            );
        }

        uint256 factor_ = $.subscriptionDurationFactors[duration_];
        if (!hasSubscriptionDebt(account_) && factor_ > 0) {
            totalCost_ = Math.mulDiv(totalCost_, factor_, PERCENTAGE_100);
        }
    }

    function getVaultNameCost(
        address token_,
        string memory vaultName_
    ) public view returns (uint256) {
        uint256 baseVaultNameCostInTokens_ = getTokenBaseVaultNameCost(token_);
        uint256 factor_ = _getVaultNameCostMultiplier(vaultName_);

        return Math.mulDiv(baseVaultNameCostInTokens_, factor_, PERCENTAGE_100);
    }

    function getAccountSubscriptionEndTime(address account_) public view returns (uint64) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.startTime == 0) {
            return uint64(block.timestamp);
        }

        return accountData.endTime;
    }

    function isAvailableForPayment(address token_) public view returns (bool) {
        return
            _getVaultSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .isAvailableForPayment;
    }

    function isSupportedSBT(address sbtToken_) public view returns (bool) {
        return _getVaultSubscriptionManagerStorage().sbtToSubscriptionTime[sbtToken_] > 0;
    }

    function getSubscriptionTimePerSBT(address sbtToken_) public view returns (uint64) {
        return _getVaultSubscriptionManagerStorage().sbtToSubscriptionTime[sbtToken_];
    }

    function hasActiveSubscription(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp < accountData.endTime;
    }

    function hasSubscriptionDebt(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp >= accountData.endTime && accountData.startTime > 0;
    }

    function getVaultName(address account_) public view returns (string memory) {
        return _getVaultSubscriptionManagerStorage().vaultNames[account_];
    }

    function getVault(string memory vaultName_) public view returns (address) {
        return _getVaultSubscriptionManagerStorage().namesToVaults[keccak256(bytes(vaultName_))];
    }

    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(BUY_SUBSCRIPTION_TYPEHASH, sender_, duration_, nonce_))
            );
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
            _getVaultSubscriptionManagerStorage().vaultNameRetentionPeriod <
            block.timestamp;

        return hasSubscriptionDebt(previousVault_) && retentionPeriodPassed_;
    }

    function _setBasePeriodDuration(uint64 newBasePeriodDuration_) internal {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        require(
            newBasePeriodDuration_ > $.basePeriodDuration,
            InvalidBasePeriodDuration(newBasePeriodDuration_)
        );

        $.basePeriodDuration = newBasePeriodDuration_;

        emit BasePeriodDurationUpdated(newBasePeriodDuration_);
    }

    function _setVaultNameRetentionPeriod(uint192 newVaultNameRetentionPeriod_) internal {
        _getVaultSubscriptionManagerStorage()
            .vaultNameRetentionPeriod = newVaultNameRetentionPeriod_;

        emit VaultNameRetentionPeriodUpdated(newVaultNameRetentionPeriod_);
    }

    function _setSubscriptionSigner(address newSubscriptionSigner_) internal {
        _checkAddress(newSubscriptionSigner_);

        _getVaultSubscriptionManagerStorage().subscriptionSigner = newSubscriptionSigner_;

        emit SubscriptionSignerUpdated(newSubscriptionSigner_);
    }

    function _updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) internal {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        for (uint256 i = 0; i < paymentTokenEntries_.length; ++i) {
            PaymentTokenUpdateEntry calldata currentEntry_ = paymentTokenEntries_[i];

            _checkAddress(currentEntry_.paymentToken);

            PaymentTokenSettings storage settings = $.paymentTokensSettings[
                currentEntry_.paymentToken
            ];

            if (!$.paymentTokens.contains(currentEntry_.paymentToken)) {
                $.paymentTokens.add(currentEntry_.paymentToken);

                settings.isAvailableForPayment = true;
            }

            settings.baseSubscriptionCost = currentEntry_.baseSubscriptionCost;
            settings.baseVaultNameCost = currentEntry_.baseVaultNameCost;

            emit PaymentTokenUpdated(
                currentEntry_.paymentToken,
                currentEntry_.baseSubscriptionCost,
                currentEntry_.baseVaultNameCost
            );
        }
    }

    function _updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) internal {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        for (uint256 i = 0; i < sbtTokenEntries_.length; ++i) {
            SBTTokenUpdateEntry calldata currentEntry_ = sbtTokenEntries_[i];

            $.sbtToSubscriptionTime[currentEntry_.sbtToken] = currentEntry_
                .subscriptionTimePerToken;

            emit SBTTokenUpdated(currentEntry_.sbtToken, currentEntry_.subscriptionTimePerToken);
        }
    }

    function _updateAccountSubscriptionCost(address account_, address token_) internal {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.accountSubscriptionCosts[token_] == 0) {
            uint256 baseTokenSubscriptionCost_ = getTokenBaseSubscriptionCost(token_);
            accountData.accountSubscriptionCosts[token_] = baseTokenSubscriptionCost_;

            emit AccountSubscriptionCostUpdated(account_, token_, baseTokenSubscriptionCost_);
        }
    }

    function _extendSubscription(address account_, uint64 duration_) internal {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        uint64 subscriptionEndTime_ = getAccountSubscriptionEndTime(account_);
        uint64 newEndTime_ = subscriptionEndTime_ + duration_;

        if (accountData.startTime == 0) {
            accountData.startTime = uint64(block.timestamp);
        }

        accountData.endTime = newEndTime_;

        emit SubscriptionExtended(account_, duration_, newEndTime_);
    }

    function _updateVaultName(address account_, string memory vaultName_) internal {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        address previousVault_ = getVault(vaultName_);

        if (previousVault_ != address(0)) {
            delete $.vaultNames[previousVault_];

            emit VaultNameReassigned(vaultName_, previousVault_, account_);
        }

        $.vaultNames[account_] = vaultName_;
        $.namesToVaults[keccak256(bytes(vaultName_))] = account_;

        emit VaultNameUpdated(account_, vaultName_);
    }

    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

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
            _getVaultSubscriptionManagerStorage().vaultFactory.isVault(account_),
            NotAVault(account_)
        );
    }

    function _onlyAvailableForPayment(address token_) internal view {
        require(isAvailableForPayment(token_), NotAvailableForPayment(token_));
    }

    function _onlySupportedSBT(address token_) internal view {
        require(isSupportedSBT(token_), NotSupportedSBT(token_));
    }

    function _checkAddress(address addr_) internal pure {
        require(addr_ != address(0), ZeroAddr());
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
