// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {ITokensPaymentModule} from "../../../interfaces/core/subscription/ITokensPaymentModule.sol";

import {TokensHelper} from "../../../libs/TokensHelper.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {SBTDiscountModule} from "./SBTDiscountModule.sol";

contract TokensPaymentModule is
    ITokensPaymentModule,
    BaseSubscriptionModule,
    SBTDiscountModule,
    Initializable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using TokensHelper for address;

    bytes32 private constant TOKENS_PAYMENT_SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.tokens.payment.subscription.module.storage");

    struct TokensPaymentModuleStorage {
        uint64 basePaymentPeriod;
        EnumerableSet.AddressSet paymentTokens;
        mapping(address => PaymentTokenData) paymentTokensData;
        mapping(uint64 => uint256) durationFactors;
    }

    modifier onlySupportedToken(address token_) {
        _onlySupportedToken(token_);
        _;
    }

    function _getTokensPaymentModuleStorage()
        private
        pure
        returns (TokensPaymentModuleStorage storage _tpms)
    {
        bytes32 slot_ = TOKENS_PAYMENT_SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly ("memory-safe") {
            _tpms.slot := slot_
        }
    }

    function __TokensPaymentModule_init(
        TokensPaymentModuleInitData calldata initData_
    ) public onlyInitializing {
        _setBasePaymentPeriod(initData_.basePaymentPeriod);

        for (uint256 i = 0; i < initData_.paymentTokenEntries.length; ++i) {
            _updatePaymentToken(
                initData_.paymentTokenEntries[i].paymentToken,
                initData_.paymentTokenEntries[i].baseSubscriptionCost
            );
        }

        for (uint256 i = 0; i < initData_.durationFactorEntries.length; ++i) {
            _updateDurationFactor(
                initData_.durationFactorEntries[i].duration,
                initData_.durationFactorEntries[i].factor
            );
        }

        for (uint256 i = 0; i < initData_.discountEntries.length; ++i) {
            _updateDiscount(
                initData_.discountEntries[i].sbtAddr,
                initData_.discountEntries[i].discount
            );
        }
    }

    /// @inheritdoc ITokensPaymentModule
    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    ) public payable virtual onlySupportedToken(token_) {
        _buySubscription(msg.sender, account_, token_, duration_, address(0));
    }

    /// @inheritdoc ITokensPaymentModule
    function buySubscriptionWithDiscount(
        address token_,
        uint64 duration_,
        address discountSBT_
    ) public payable virtual onlySupportedToken(token_) {
        _validateDiscount(discountSBT_, msg.sender);

        _buySubscription(msg.sender, msg.sender, token_, duration_, discountSBT_);
    }

    /// @inheritdoc ITokensPaymentModule
    function getBasePaymentPeriod() public view virtual returns (uint64) {
        return _getTokensPaymentModuleStorage().basePaymentPeriod;
    }

    /// @inheritdoc ITokensPaymentModule
    function getSubscriptionDurationFactor(uint64 duration_) public view returns (uint256) {
        return _getTokensPaymentModuleStorage().durationFactors[duration_];
    }

    /// @inheritdoc ITokensPaymentModule
    function getPaymentTokens() public view returns (address[] memory) {
        return _getTokensPaymentModuleStorage().paymentTokens.values();
    }

    /// @inheritdoc ITokensPaymentModule
    function getSubscriptionCost(
        address account_,
        address token_,
        uint64 duration_
    ) public view onlySupportedToken(token_) returns (uint256 totalCost_) {
        require(duration_ > 0, ZeroDuration());

        uint256 basePeriodDuration_ = getBasePaymentPeriod();
        uint256 subscriptionCostInTokens_ = getAccountBaseSubscriptionCost(account_, token_);

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

        return _applyDurationFactor(account_, duration_, totalCost_);
    }

    /// @inheritdoc ITokensPaymentModule
    function getSubscriptionCostWithDiscount(
        address account_,
        address token_,
        uint64 duration_,
        address discountSBT_
    ) public view onlySupportedToken(token_) returns (uint256) {
        uint256 totalCost_ = getSubscriptionCost(account_, token_, duration_);

        return _applyDiscount(totalCost_, getDiscount(discountSBT_));
    }

    /// @inheritdoc ITokensPaymentModule
    function getTokenBaseSubscriptionCost(address token_) public view virtual returns (uint256) {
        return _getTokensPaymentModuleStorage().paymentTokensData[token_].baseSubscriptionCost;
    }

    /// @inheritdoc ITokensPaymentModule
    function getAccountSavedSubscriptionCost(
        address account_,
        address token_
    ) public view virtual returns (uint256) {
        return
            _getTokensPaymentModuleStorage().paymentTokensData[token_].accountsSubscriptionCost[
                account_
            ];
    }

    /// @inheritdoc ITokensPaymentModule
    function getAccountBaseSubscriptionCost(
        address account_,
        address token_
    ) public view virtual returns (uint256) {
        uint256 accountSavedCost_ = getAccountSavedSubscriptionCost(account_, token_);
        uint256 currentCost_ = getTokenBaseSubscriptionCost(token_);

        return accountSavedCost_ > 0 ? Math.min(accountSavedCost_, currentCost_) : currentCost_;
    }

    /// @inheritdoc ITokensPaymentModule
    function isSupportedToken(address paymentToken_) public view virtual returns (bool) {
        return _getTokensPaymentModuleStorage().paymentTokens.contains(paymentToken_);
    }

    function _setBasePaymentPeriod(uint64 newBasePaymentPeriod_) internal virtual {
        _getTokensPaymentModuleStorage().basePaymentPeriod = newBasePaymentPeriod_;

        emit BasePaymentPeriodUpdated(newBasePaymentPeriod_);
    }

    function _updateDurationFactor(uint64 duration_, uint256 factor_) internal virtual {
        _getTokensPaymentModuleStorage().durationFactors[duration_] = factor_;

        emit SubscriptionDurationFactorUpdated(duration_, factor_);
    }

    function _withdrawTokens(address tokenAddr_, address to_, uint256 amount_) internal virtual {
        _checkAddress(to_, "To");

        amount_ = tokenAddr_.sendTokens(to_, amount_);

        emit TokensWithdrawn(tokenAddr_, to_, amount_);
    }

    function _updatePaymentToken(
        address paymentToken_,
        uint256 baseSubscriptionCost_
    ) internal virtual {
        if (!isSupportedToken(paymentToken_)) {
            _addPaymentToken(paymentToken_);
        }

        _setBaseSubscriptionCost(paymentToken_, baseSubscriptionCost_);
    }

    function _addPaymentToken(address paymentToken_) internal virtual {
        _checkAddress(paymentToken_, "PaymentToken");

        require(
            _getTokensPaymentModuleStorage().paymentTokens.add(paymentToken_),
            PaymentTokenAlreadyAdded(paymentToken_)
        );

        emit PaymentTokenAdded(paymentToken_);
    }

    function _removePaymentToken(address paymentToken_) internal virtual {
        TokensPaymentModuleStorage storage $ = _getTokensPaymentModuleStorage();

        _onlySupportedToken(paymentToken_);

        $.paymentTokens.remove(paymentToken_);
        delete $.paymentTokensData[paymentToken_].baseSubscriptionCost;

        emit PaymentTokenRemoved(paymentToken_);
    }

    function _setBaseSubscriptionCost(
        address paymentToken_,
        uint256 newSubscriptionCost_
    ) internal virtual {
        _getTokensPaymentModuleStorage()
            .paymentTokensData[paymentToken_]
            .baseSubscriptionCost = newSubscriptionCost_;

        emit BaseSubscriptionCostUpdated(paymentToken_, newSubscriptionCost_);
    }

    function _buySubscription(
        address buyer_,
        address account_,
        address token_,
        uint64 duration_,
        address discountSBT_
    ) internal virtual {
        require(duration_ >= getBasePaymentPeriod(), InvalidSubscriptionDuration(duration_));

        uint256 totalCost_ = getSubscriptionCostWithDiscount(
            account_,
            token_,
            duration_,
            discountSBT_
        );

        _updateAccountTokenSubscriptionCost(account_, token_);

        token_.receiveTokens(buyer_, totalCost_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithToken(token_, buyer_, totalCost_);
    }

    function _updateAccountTokenSubscriptionCost(
        address account_,
        address token_
    ) internal virtual {
        TokensPaymentModuleStorage storage $ = _getTokensPaymentModuleStorage();

        if ($.paymentTokensData[token_].accountsSubscriptionCost[account_] == 0) {
            uint256 baseTokenSubscriptionCost_ = getTokenBaseSubscriptionCost(token_);
            $.paymentTokensData[token_].accountsSubscriptionCost[
                account_
            ] = baseTokenSubscriptionCost_;

            emit AccountTokenSubscriptionCostUpdated(account_, token_, baseTokenSubscriptionCost_);
        }
    }

    function _applyDurationFactor(
        address account_,
        uint64 duration_,
        uint256 currentCost_
    ) internal view virtual returns (uint256) {
        uint256 factor_ = getSubscriptionDurationFactor(duration_);

        if (hasSubscriptionDebt(account_) || factor_ == 0) {
            return currentCost_;
        }

        return Math.mulDiv(currentCost_, factor_, PERCENTAGE_100);
    }

    function _onlySupportedToken(address token_) internal view {
        require(isSupportedToken(token_), TokenNotSupported(token_));
    }
}
