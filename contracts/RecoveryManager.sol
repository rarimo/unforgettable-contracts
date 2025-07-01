// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {SetHelper} from "@solarity/solidity-lib/libs/arrays/SetHelper.sol";
import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IRecoveryManager} from "./interfaces/IRecoveryManager.sol";
import {IRecoveryStrategy} from "./interfaces/IRecoveryStrategy.sol";

import {StrategiesModule} from "./modules/StrategiesModule.sol";
import {SubscriptionModule} from "./modules/SubscriptionModule.sol";
import {TokensPriceModule} from "./modules/TokensPriceModule.sol";
import {TokensWhitelistModule} from "./modules/TokensWhitelistModule.sol";

contract RecoveryManager is
    IRecoveryManager,
    OwnableUpgradeable,
    StrategiesModule,
    SubscriptionModule,
    TokensWhitelistModule
{
    using EnumerableSet for *;
    using SetHelper for *;
    using SafeERC20 for IERC20;

    bytes32 public constant RECOVERY_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.recovery.manager.storage");

    struct RecoveryManagerStorage {
        mapping(address => bool) subscribedAccounts;
    }

    error AccountAlreadySubscribed(address account);
    error AccountNotSubscribed(address account);
    error UnableToPayWithNativeCurrency();
    error NotAuthorizedForSubscription(address account, uint256 subscriptionId);
    error SubscriptionEnded(uint256 subscriptionId_);

    event SubscriptionBought(
        address indexed account,
        uint256 subscriptionId,
        uint256 duration,
        address tokenAddr,
        uint256 tokensAmount
    );

    modifier onlySubscribedAccount() {
        _onlySubscribedAccount(msg.sender);
        _;
    }

    modifier onlyAccountSubscription(uint256 subscriptionId_) {
        _onlyAccountSubscription(msg.sender, subscriptionId_);
        _;
    }

    function _getRecoveryManagerStorage()
        private
        pure
        returns (RecoveryManagerStorage storage _rms)
    {
        bytes32 slot_ = RECOVERY_MANAGER_STORAGE_SLOT;

        assembly {
            _rms.slot := slot_
        }
    }

    function initialize(address priceManager_, uint64 basePeriodDuration_) external initializer {
        __Ownable_init(msg.sender);

        _setPriceManager(priceManager_);
        _setBasePeriodDuration(basePeriodDuration_);
    }

    /**********************************************************************************************/
    /*** `Whitelist` management                                                                 ***/
    /**********************************************************************************************/

    function updateWhitelistedTokens(
        address[] calldata tokensToUpdate_,
        bool isAdding_
    ) external onlyOwner {
        if (isAdding_) {
            _addTokensToWhitelist(tokensToUpdate_);
        } else {
            _removeTokensFromWhitelist(tokensToUpdate_);
        }
    }

    /**********************************************************************************************/
    /*** `Subscription Periods` management                                                      ***/
    /**********************************************************************************************/

    function updateSubscriptionPeriods(
        SubscriptionPeriodUpdateEntry[] calldata subscriptionPeriodUpdateEntries_
    ) external onlyOwner {
        for (uint256 i = 0; i < subscriptionPeriodUpdateEntries_.length; i++) {
            _updateSubscriptionPeriod(
                uint64(subscriptionPeriodUpdateEntries_[i].duration),
                subscriptionPeriodUpdateEntries_[i].strategiesCostFactor
            );
        }
    }

    function removeSubscriptionPeriods(uint256[] calldata periodsToRemove_) external onlyOwner {
        for (uint256 i = 0; i < periodsToRemove_.length; i++) {
            _removeSubscriptionPeriod(uint64(periodsToRemove_[i]));
        }
    }

    /**********************************************************************************************/
    /*** `Strategies` management                                                                ***/
    /**********************************************************************************************/

    function addRecoveryStrategies(NewStrategyInfo[] calldata newStrategies_) external onlyOwner {
        for (uint256 i = 0; i < newStrategies_.length; i++) {
            _addStrategy(newStrategies_[i].strategy, newStrategies_[i].baseRecoveryCostInUsd);
        }
    }

    function disableStrategy(uint256 strategyId_) external onlyOwner {
        _disableStrategy(strategyId_);
    }

    function enableStrategy(uint256 strategyId_) external onlyOwner {
        _enableStrategy(strategyId_);
    }

    /**********************************************************************************************/
    /*** `Tokens Withdrawals` management                                                        ***/
    /**********************************************************************************************/

    function withdrawTokens(address tokenAddr_, address recipient_) external onlyOwner {
        if (!isNativeToken(tokenAddr_)) {
            _transferERC20Tokens(tokenAddr_, address(this), recipient_, type(uint256).max);
        } else {
            Address.sendValue(payable(recipient_), address(this).balance);
        }
    }

    /**********************************************************************************************/
    /*** `IRecoveryProvider` logic                                                              ***/
    /**********************************************************************************************/

    function subscribe(bytes memory subscribeDataRaw_) external {
        require(!isAccountSubscribed(msg.sender), AccountAlreadySubscribed(msg.sender));

        NewSubscriptionData memory subscribeData_ = abi.decode(
            subscribeDataRaw_,
            (NewSubscriptionData)
        );

        if (subscribeData_.recoveryMethods.length > 0) {
            require(!isNativeToken(subscribeData_.tokenAddr), UnableToPayWithNativeCurrency());

            _buyNewSubscription(subscribeData_);
        } else {
            _hasActiveSubscription(msg.sender);
        }

        _getRecoveryManagerStorage().subscribedAccounts[msg.sender] = true;

        emit AccountSubscribed(msg.sender);
    }

    function unsubscribe() external onlySubscribedAccount {
        delete _getRecoveryManagerStorage().subscribedAccounts[msg.sender];

        emit AccountUnsubscribed(msg.sender);
    }

    function recover(
        address newOwner_,
        bytes calldata recoveryProof_
    ) external onlySubscribedAccount {
        _hasActiveSubscription(msg.sender);

        uint256 currentSubscriptionId_ = getCurrentAccountSubscriptionId(msg.sender);
    }

    function getRecoveryData(address account_) external view returns (bytes memory) {
        uint256 subscriptionId_ = getCurrentAccountSubscriptionId(account_);

        require(subscriptionId_ > 0, NoActiveSubscription(account_));

        AccountRecoveryData memory recoveryData_ = AccountRecoveryData({
            recoverySecurityPercentage: getSubscriptionRecoverySecurityPercentage(subscriptionId_),
            recoveryMethods: getSubscriptionActiveRecoveryMethods(subscriptionId_)
        });

        return abi.encode(recoveryData_);
    }

    /**********************************************************************************************/
    /*** `Account Subscriptions` management                                                     ***/
    /**********************************************************************************************/

    function buyNewSubscription(
        NewSubscriptionData calldata subscriptionData_
    ) external payable onlySubscribedAccount {
        _buyNewSubscription(subscriptionData_);
    }

    function extendSubscription(
        uint256 subscriptionId_,
        uint256 duration_,
        address tokenAddr_
    ) external payable {
        _onlyWhitelistedToken(tokenAddr_);

        _extendSubscription(subscriptionId_, duration_);

        uint256 extensionCostInUsd_ = getSubscriptionExtensionCostInUsd(
            duration_,
            subscriptionId_
        );
        uint256 extensionCostInTokens_ = getAmountFromUsd(tokenAddr_, extensionCostInUsd_);

        if (!isNativeToken(tokenAddr_)) {
            _transferERC20Tokens(tokenAddr_, msg.sender, address(this), extensionCostInTokens_);
        } else {
            _receiveNative(msg.sender, extensionCostInTokens_);
        }
    }

    function addRecoveryMethod(
        uint256 subscriptionId_,
        address tokenAddr_,
        RecoveryMethod calldata newRecoveryMethod_
    ) external payable onlySubscribedAccount onlyAccountSubscription(subscriptionId_) {
        _validateRecoveryMethod(newRecoveryMethod_);

        _addRecoveryMethod(subscriptionId_, newRecoveryMethod_);

        uint256 leftPeriodsInSubscription_ = getLeftPeriodsInSubscription(subscriptionId_);

        require(leftPeriodsInSubscription_ > 0, SubscriptionEnded(subscriptionId_));

        uint256 costInUsd_ = getRecoveryCostInUsdByPeriods(
            newRecoveryMethod_.strategyId,
            leftPeriodsInSubscription_
        );
        uint256 tokensAmount_ = getAmountFromUsd(tokenAddr_, costInUsd_);

        if (!isNativeToken(tokenAddr_)) {
            _transferERC20Tokens(tokenAddr_, msg.sender, address(this), tokensAmount_);
        } else {
            _receiveNative(msg.sender, tokensAmount_);
        }
    }

    function removeRecoveryMethod(
        uint256 subscriptionId_,
        uint256 recoveryMethodId_
    ) external onlySubscribedAccount onlyAccountSubscription(subscriptionId_) {
        _removeRecoveryMethod(subscriptionId_, recoveryMethodId_);
    }

    function changeRecoverySecurityPercentage(
        uint256 subscriptionId_,
        uint256 newRecoverySecurityPercentage_
    ) external onlySubscribedAccount onlyAccountSubscription(subscriptionId_) {
        _changeRecoverySecurityPercentage(subscriptionId_, newRecoverySecurityPercentage_);
    }

    function changeRecoveryData(
        uint256 subscriptionId_,
        uint256 recoveryMethodId_,
        bytes calldata newRecoveryData_
    ) external onlySubscribedAccount onlyAccountSubscription(subscriptionId_) {
        RecoveryMethod memory recoveryMethod_ = getActiveRecoveryMethod(
            subscriptionId_,
            recoveryMethodId_
        );

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).validateAccountRecoveryData(
            newRecoveryData_
        );

        _changeRecoveryData(subscriptionId_, recoveryMethodId_, newRecoveryData_);
    }

    /**********************************************************************************************/
    /*** Getters                                                                                ***/
    /**********************************************************************************************/

    function getSubscriptionExtensionCostInUsd(
        uint256 subscriptionId_,
        uint256 duration_
    ) public view returns (uint256) {
        return
            getSubscriptionCostInUsd(
                duration_,
                getSubscriptionActiveRecoveryMethods(subscriptionId_)
            );
    }

    function getSubscriptionCostInUsd(
        uint256 duration_,
        RecoveryMethod[] memory recoveryMethods_
    ) public view returns (uint256) {
        uint256 basePeriodsCount_ = getPeriodsCountByTime(duration_);

        uint256 totalBaseCostInUsd_;
        for (uint256 i = 0; i < recoveryMethods_.length; i++) {
            totalBaseCostInUsd_ += getRecoveryCostInUsdByPeriods(
                recoveryMethods_[i].strategyId,
                basePeriodsCount_
            );
        }

        return
            Math.mulDiv(
                totalBaseCostInUsd_,
                getSubscriptionPeriodFactor(duration_),
                PERCENTAGE_100
            );
    }

    function isAccountSubscribed(address account_) public view returns (bool) {
        return _getRecoveryManagerStorage().subscribedAccounts[account_];
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function _buyNewSubscription(NewSubscriptionData memory subscriptionData_) internal {
        _onlyWhitelistedToken(subscriptionData_.tokenAddr);

        for (uint256 i = 0; i < subscriptionData_.recoveryMethods.length; i++) {
            _validateRecoveryMethod(subscriptionData_.recoveryMethods[i]);
        }

        uint256 subscriptionId_ = _createNewSubscription(
            msg.sender,
            subscriptionData_.subscriptionDuration,
            subscriptionData_.recoverySecurityPercentage,
            subscriptionData_.recoveryMethods
        );

        uint256 subscriptionCostInUsd_ = getSubscriptionCostInUsd(
            subscriptionData_.subscriptionDuration,
            subscriptionData_.recoveryMethods
        );
        uint256 subscriptionCostInTokens_ = getAmountFromUsd(
            subscriptionData_.tokenAddr,
            subscriptionCostInUsd_
        );

        if (!isNativeToken(subscriptionData_.tokenAddr)) {
            _transferERC20Tokens(
                subscriptionData_.tokenAddr,
                msg.sender,
                address(this),
                subscriptionCostInTokens_
            );
        } else {
            _receiveNative(msg.sender, subscriptionCostInTokens_);
        }

        emit SubscriptionBought(
            msg.sender,
            subscriptionId_,
            subscriptionData_.subscriptionDuration,
            subscriptionData_.tokenAddr,
            subscriptionCostInTokens_
        );
    }

    function _transferERC20Tokens(
        address tokenAddr_,
        address from_,
        address to_,
        uint256 amount_
    ) internal {
        amount_ = Math.min(amount_, IERC20(tokenAddr_).balanceOf(from_));

        if (from_ == address(this)) {
            IERC20(tokenAddr_).safeTransfer(to_, amount_);
        } else {
            IERC20(tokenAddr_).safeTransferFrom(from_, to_, amount_);
        }
    }

    function _receiveNative(address from_, uint256 amount_) internal {
        require(msg.value >= amount_);

        uint256 extraValue_ = msg.value - amount_;
        if (extraValue_ > 0) {
            Address.sendValue(payable(from_), extraValue_);
        }
    }

    function _validateRecoveryMethod(RecoveryMethod memory recoveryMethod_) internal view {
        _hasStrategyStatus(recoveryMethod_.strategyId, StrategyStatus.Active);

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).validateAccountRecoveryData(
            recoveryMethod_.recoveryData
        );
    }

    function _onlySubscribedAccount(address account_) internal view {
        require(isAccountSubscribed(account_), AccountNotSubscribed(account_));
    }

    function _onlyAccountSubscription(address account_, uint256 subscriptionId_) internal view {
        require(
            getSubscriptionAccount(subscriptionId_) == account_,
            NotAuthorizedForSubscription(account_, subscriptionId_)
        );
    }
}
