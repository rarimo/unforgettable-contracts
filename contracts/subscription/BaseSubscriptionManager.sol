// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {ISubscriptionManager} from "../interfaces/subscription/ISubscriptionManager.sol";
import {TokensHelper} from "../libs/TokensHelper.sol";

import {BaseSubscriptionModule} from "./modules/BaseSubscriptionModule.sol";

contract BaseSubscriptionManager is
    ISubscriptionManager,
    BaseSubscriptionModule,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for *;
    using TokensHelper for address;

    bytes32 public constant BASE_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.subscription.manager.storage");

    struct BaseSubscriptionManagerStorage {
        address recoveryManager;
        uint64 basePeriodDuration;
        // TokensSettings
        EnumerableSet.AddressSet paymentTokens;
        mapping(address => PaymentTokenSettings) paymentTokensSettings;
        // Subscription duration factors
        mapping(uint64 => uint256) subscriptionDurationFactors;
    }

    modifier onlyAvailableForPayment(address token_) {
        _onlyAvailableForPayment(token_);
        _;
    }

    modifier onlyRecoveryManager() {
        _onlyRecoveryManager();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function _getBaseSubscriptionManagerStorage()
        private
        pure
        returns (BaseSubscriptionManagerStorage storage _bsms)
    {
        bytes32 slot_ = BASE_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly {
            _bsms.slot := slot_
        }
    }

    function __BaseSubscriptionManager_init(
        address recoveryManager_,
        uint64 basePeriodDuration_,
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) public onlyInitializing {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _setRecoveryManager(recoveryManager_);

        _setBasePeriodDuration(basePeriodDuration_);

        _updatePaymentTokens(paymentTokenEntries_);
    }

    function updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) external onlyOwner {
        _updatePaymentTokens(paymentTokenEntries_);
    }

    function updateTokenPaymentStatus(address token_, bool newStatus_) external onlyOwner {
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

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
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

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

    function activateSubscription(address account_) external onlyRecoveryManager {
        require(!hasSubscription(account_), AccountAlreadyActivated(account_));

        AccountSubscriptionData storage accountData = _getAccountSubscriptionData(account_);

        accountData.startTime = uint64(block.timestamp);
        accountData.endTime = uint64(block.timestamp);

        emit AccountActivated(account_, block.timestamp);
    }

    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    ) external payable virtual onlyAvailableForPayment(token_) nonReentrant {
        _buySubscription(account_, token_, duration_);
    }

    function getBasePeriodDuration() external view returns (uint64) {
        return _getBaseSubscriptionManagerStorage().basePeriodDuration;
    }

    function getPaymentTokens() external view returns (address[] memory) {
        return _getBaseSubscriptionManagerStorage().paymentTokens.values();
    }

    function getPaymentTokensSettings(
        address token_
    ) external view returns (PaymentTokenSettings memory) {
        return _getBaseSubscriptionManagerStorage().paymentTokensSettings[token_];
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function getRecoveryManager() external view returns (address) {
        return _getBaseSubscriptionManagerStorage().recoveryManager;
    }

    function getSubscriptionDurationFactor(uint64 duration_) external view returns (uint256) {
        return _getBaseSubscriptionManagerStorage().subscriptionDurationFactors[duration_];
    }

    function getTokenBaseSubscriptionCost(address token_) public view returns (uint256) {
        return
            _getBaseSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .baseSubscriptionCost;
    }

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) public view returns (uint256) {
        uint256 accountSavedCost_ = _getAccountSubscriptionData(account_).accountSubscriptionCosts[
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
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

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

    function isAvailableForPayment(address token_) public view returns (bool) {
        return
            _getBaseSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .isAvailableForPayment;
    }

    function _setRecoveryManager(address newRecoveryManager_) internal {
        _checkAddress(newRecoveryManager_);

        _getBaseSubscriptionManagerStorage().recoveryManager = newRecoveryManager_;

        emit RecoveryManagerUpdated(newRecoveryManager_);
    }

    function _setBasePeriodDuration(uint64 newBasePeriodDuration_) internal {
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

        require(
            newBasePeriodDuration_ > $.basePeriodDuration,
            InvalidBasePeriodDuration(newBasePeriodDuration_)
        );

        $.basePeriodDuration = newBasePeriodDuration_;

        emit BasePeriodDurationUpdated(newBasePeriodDuration_);
    }

    function _updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) internal {
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

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

    function _updateAccountSubscriptionCost(address account_, address token_) internal {
        AccountSubscriptionData storage accountData = _getAccountSubscriptionData(account_);

        if (accountData.accountSubscriptionCosts[token_] == 0) {
            uint256 baseTokenSubscriptionCost_ = getTokenBaseSubscriptionCost(token_);
            accountData.accountSubscriptionCosts[token_] = baseTokenSubscriptionCost_;

            emit AccountSubscriptionCostUpdated(account_, token_, baseTokenSubscriptionCost_);
        }
    }

    function _buySubscription(address account_, address token_, uint64 duration_) internal {
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

        require(duration_ >= $.basePeriodDuration, InvalidSubscriptionDuration(duration_));

        uint256 totalCost_ = getSubscriptionCost(account_, token_, duration_);

        _updateAccountSubscriptionCost(account_, token_);

        token_.receiveTokens(msg.sender, totalCost_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithToken(token_, msg.sender, totalCost_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _onlyAvailableForPayment(address token_) internal view {
        require(isAvailableForPayment(token_), NotAvailableForPayment(token_));
    }

    function _onlyRecoveryManager() internal view {
        BaseSubscriptionManagerStorage storage $ = _getBaseSubscriptionManagerStorage();

        require(msg.sender == $.recoveryManager, NotARecoveryManager(msg.sender));
    }
}
