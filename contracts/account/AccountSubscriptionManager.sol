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

import {IAccountSubscriptionManager} from "../interfaces/account/IAccountSubscriptionManager.sol";
import {IBurnableSBT} from "../interfaces/tokens/IBurnableSBT.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";
import {EIP712SignatureChecker} from "../libs/EIP712SignatureChecker.sol";

contract AccountSubscriptionManager is
    IAccountSubscriptionManager,
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

    bytes32 public constant SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscription.manager.storage");

    struct SubscriptionManagerStorage {
        uint64 basePeriodDuration;
        address subscriptionSigner;
        // TokensSettings
        EnumerableSet.AddressSet paymentTokens;
        mapping(address => PaymentTokenSettings) paymentTokensSettings;
        mapping(address => uint64) sbtToSubscriptionTime;
        // Subscription duration factors
        mapping(uint64 => uint256) subscriptionDurationFactors;
        // Accounts subscription data
        mapping(address => AccountSubscriptionData) accountsSubscriptionData;
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

    function _getSubscriptionManagerStorage()
        private
        pure
        returns (SubscriptionManagerStorage storage _sms)
    {
        bytes32 slot_ = SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly {
            _sms.slot := slot_
        }
    }

    function initialize(
        uint64 basePeriodDuration_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __Ownable_init(msg.sender);
        __EIP712_init("SubscriptionManager", "v1.0.0");
        __ReentrancyGuard_init();

        _setBasePeriodDuration(basePeriodDuration_);
        _setSubscriptionSigner(subscriptionSigner_);

        _updatePaymentTokens(paymentTokenEntries_);
        _updateSBTTokens(sbtTokenEntries_);
    }

    function setSubscriptionSigner(address newSubscriptionSigner_) external onlyOwner {
        _setSubscriptionSigner(newSubscriptionSigner_);
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
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

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
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

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
    ) external payable virtual onlyAvailableForPayment(token_) nonReentrant {
        _buySubscription(account_, token_, duration_);
    }

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external virtual onlySupportedSBT(sbtTokenAddr_) {
        _buySubscriptionWithSBT(account_, sbtTokenAddr_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external virtual {
        _buySubscriptionWithSignature(account_, duration_, signature_);
    }

    function getBasePeriodDuration() external view returns (uint64) {
        return _getSubscriptionManagerStorage().basePeriodDuration;
    }

    function getSubscriptionSigner() external view returns (address) {
        return _getSubscriptionManagerStorage().subscriptionSigner;
    }

    function getPaymentTokens() external view returns (address[] memory) {
        return _getSubscriptionManagerStorage().paymentTokens.values();
    }

    function getPaymentTokensSettings(
        address token_
    ) external view returns (PaymentTokenSettings memory) {
        return _getSubscriptionManagerStorage().paymentTokensSettings[token_];
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256) {
        return _getSubscriptionManagerStorage().subscriptionDurationFactors[duration_];
    }

    function getTokenBaseSubscriptionCost(address token_) public view returns (uint256) {
        return _getSubscriptionManagerStorage().paymentTokensSettings[token_].baseSubscriptionCost;
    }

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) public view returns (uint256) {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

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
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

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

    function getAccountSubscriptionEndTime(address account_) public view returns (uint64) {
        AccountSubscriptionData storage accountData = _getSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.startTime == 0) {
            return uint64(block.timestamp);
        }

        return accountData.endTime;
    }

    function isAvailableForPayment(address token_) public view returns (bool) {
        return
            _getSubscriptionManagerStorage().paymentTokensSettings[token_].isAvailableForPayment;
    }

    function isSupportedSBT(address sbtToken_) public view returns (bool) {
        return _getSubscriptionManagerStorage().sbtToSubscriptionTime[sbtToken_] > 0;
    }

    function getSubscriptionTimePerSBT(address sbtToken_) public view returns (uint64) {
        return _getSubscriptionManagerStorage().sbtToSubscriptionTime[sbtToken_];
    }

    function hasActiveSubscription(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp < accountData.endTime;
    }

    function hasSubscriptionDebt(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp >= accountData.endTime && accountData.startTime > 0;
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

    function _setBasePeriodDuration(uint64 newBasePeriodDuration_) internal {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

        require(
            newBasePeriodDuration_ > $.basePeriodDuration,
            InvalidBasePeriodDuration(newBasePeriodDuration_)
        );

        $.basePeriodDuration = newBasePeriodDuration_;

        emit BasePeriodDurationUpdated(newBasePeriodDuration_);
    }

    function _setSubscriptionSigner(address newSubscriptionSigner_) internal {
        _checkAddress(newSubscriptionSigner_);

        _getSubscriptionManagerStorage().subscriptionSigner = newSubscriptionSigner_;

        emit SubscriptionSignerUpdated(newSubscriptionSigner_);
    }

    function _updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) internal {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

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

            emit PaymentTokenUpdated(
                currentEntry_.paymentToken,
                currentEntry_.baseSubscriptionCost
            );
        }
    }

    function _updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) internal {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

        for (uint256 i = 0; i < sbtTokenEntries_.length; ++i) {
            SBTTokenUpdateEntry calldata currentEntry_ = sbtTokenEntries_[i];

            $.sbtToSubscriptionTime[currentEntry_.sbtToken] = currentEntry_
                .subscriptionTimePerToken;

            emit SBTTokenUpdated(currentEntry_.sbtToken, currentEntry_.subscriptionTimePerToken);
        }
    }

    function _updateAccountSubscriptionCost(address account_, address token_) internal {
        AccountSubscriptionData storage accountData = _getSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.accountSubscriptionCosts[token_] == 0) {
            uint256 baseTokenSubscriptionCost_ = getTokenBaseSubscriptionCost(token_);
            accountData.accountSubscriptionCosts[token_] = baseTokenSubscriptionCost_;

            emit AccountSubscriptionCostUpdated(account_, token_, baseTokenSubscriptionCost_);
        }
    }

    function _buySubscription(address account_, address token_, uint64 duration_) internal {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

        require(duration_ >= $.basePeriodDuration, InvalidSubscriptionDuration(duration_));

        uint256 totalCost_ = getSubscriptionCost(account_, token_, duration_);

        _updateAccountSubscriptionCost(account_, token_);

        token_.receiveTokens(msg.sender, totalCost_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithToken(token_, msg.sender, totalCost_);
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

    function _buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) internal {
        SubscriptionManagerStorage storage $ = _getSubscriptionManagerStorage();

        uint256 currentNonce_ = _useNonce(msg.sender);
        bytes32 buySubscriptionHash_ = hashBuySubscription(msg.sender, duration_, currentNonce_);
        $.subscriptionSigner.checkSignature(buySubscriptionHash_, signature_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithSignature(msg.sender, duration_, currentNonce_);
    }

    function _extendSubscription(address account_, uint64 duration_) internal {
        AccountSubscriptionData storage accountData = _getSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        uint64 subscriptionEndTime_ = getAccountSubscriptionEndTime(account_);
        uint64 newEndTime_ = subscriptionEndTime_ + duration_;

        if (accountData.startTime == 0) {
            accountData.startTime = uint64(block.timestamp);
        }

        accountData.endTime = newEndTime_;

        emit SubscriptionExtended(account_, duration_, newEndTime_);
    }

    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _onlyAvailableForPayment(address token_) internal view {
        require(isAvailableForPayment(token_), NotAvailableForPayment(token_));
    }

    function _onlySupportedSBT(address token_) internal view {
        require(isSupportedSBT(token_), NotSupportedSBT(token_));
    }

    function _checkAddress(address addr_) internal pure {
        require(addr_ != address(0), ZeroAddr());
    }
}
