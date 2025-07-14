// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";

contract VaultSubscriptionManager is IVaultSubscriptionManager, OwnableUpgradeable {
    using EnumerableSet for *;
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 public constant VAULT_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.subscription.manager.storage");

    modifier onlyAvailableForPayment(address token_) {
        _onlyAvailableForPayment(token_);
        _;
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
        address vaultFactoryAddr_
    ) external initializer {
        __Ownable_init(msg.sender);

        _setBasePeriodDuration(basePeriodDuration_);
        _getVaultSubscriptionManagerStorage().vaultFactory = IVaultFactory(vaultFactoryAddr_);
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
        uint256 duration_,
        uint256 factor_
    ) external onlyOwner {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        $.subscriptionDurationFactors[duration_] = factor_;

        emit SubscriptionDurationFactorUpdated(duration_, factor_);
    }

    function withdrawTokens(address tokenAddr_, address to_, uint256 amount_) external onlyOwner {
        require(to_ != address(0), ZeroTokensRecipient());

        _sendTokens(tokenAddr_, to_, amount_);
    }

    function buySubscription(
        address account_,
        address token_,
        uint256 duration_
    ) external payable onlyAvailableForPayment(token_) {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        require(duration_ >= $.basePeriodDuration, InvalidSubscriptionDuration(duration_));
        require($.vaultFactory.isVault(account_), NotAVault(account_));

        AccountSubscriptionData storage accountData = $.accountsSubscriptionData[account_];

        uint256 currentSubscriptionsEndTime_ = getAccountSubscriptionEndTime(account_);

        if (accountData.startTime == 0) {
            accountData.startTime = uint64(block.timestamp);
        }

        uint64 newEndTime_ = uint64(currentSubscriptionsEndTime_ + duration_);

        accountData.endTime = newEndTime_;

        uint256 totalCost_ = getSubscriptionCost(account_, token_, duration_);

        _updateAccountSubscriptionCost(account_, token_);

        _receiveTokens(token_, msg.sender, totalCost_);

        emit SubscriptionExtended(account_, token_, duration_, totalCost_, newEndTime_);
    }

    function getTokenBaseSubscriptionCost(address token_) public view returns (uint256) {
        return
            _getVaultSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .baseSubscriptionCost;
    }

    function getBaseSubscriptionCostForAccount(
        address account_,
        address token_
    ) public view returns (uint256) {
        VaultSubscriptionManagerStorage storage $ = _getVaultSubscriptionManagerStorage();

        uint256 accountSavedCost_ = $.accountsSubscriptionData[account_].accountSubscriptionCosts[
            token_
        ];

        return accountSavedCost_ > 0 ? accountSavedCost_ : getTokenBaseSubscriptionCost(token_);
    }

    function getSubscriptionCost(
        address account_,
        address token_,
        uint256 duration_
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
        if (!hasExpiredSubscription(account_) && factor_ > 0) {
            totalCost_ = Math.mulDiv(totalCost_, factor_, PERCENTAGE_100);
        }
    }

    function getAccountSubscriptionEndTime(address account_) public view returns (uint256) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.startTime == 0) {
            return block.timestamp;
        }

        return accountData.endTime;
    }

    function isAvailableForPayment(address token_) public view returns (bool) {
        return
            _getVaultSubscriptionManagerStorage()
                .paymentTokensSettings[token_]
                .isAvailableForPayment;
    }

    function hasActiveSubscription(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp < accountData.endTime;
    }

    function hasExpiredSubscription(address account_) public view returns (bool) {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        return block.timestamp >= accountData.endTime && accountData.startTime > 0;
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

    function _updateAccountSubscriptionCost(address account_, address token_) internal {
        AccountSubscriptionData storage accountData = _getVaultSubscriptionManagerStorage()
            .accountsSubscriptionData[account_];

        if (accountData.accountSubscriptionCosts[token_] == 0) {
            uint256 baseTokenSubscriptionCost_ = getTokenBaseSubscriptionCost(token_);
            accountData.accountSubscriptionCosts[token_] = baseTokenSubscriptionCost_;

            emit AccountSubscriptionCostUpdated(account_, token_, baseTokenSubscriptionCost_);
        }
    }

    function _receiveTokens(address tokenAddr_, address from_, uint256 amount_) internal {
        if (tokenAddr_ == ETH_ADDR) {
            require(msg.value >= amount_, NotEnoughNativeCurrency(amount_, msg.value));

            uint256 extraValue_ = msg.value - amount_;
            if (extraValue_ > 0) {
                Address.sendValue(payable(from_), extraValue_);
            }
        } else {
            IERC20(tokenAddr_).safeTransferFrom(from_, address(this), amount_);
        }
    }

    function _sendTokens(address tokenAddr_, address to_, uint256 amount_) internal {
        if (tokenAddr_ == ETH_ADDR) {
            amount_ = Math.min(amount_, address(this).balance);

            Address.sendValue(payable(to_), amount_);
        } else {
            amount_ = Math.min(amount_, IERC20(tokenAddr_).balanceOf(address(this)));

            IERC20(tokenAddr_).safeTransfer(to_, amount_);
        }
    }

    function _onlyAvailableForPayment(address token_) internal view {
        require(isAvailableForPayment(token_), NotAvailableForPayment(token_));
    }
}
