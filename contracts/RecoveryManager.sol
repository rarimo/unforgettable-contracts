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
import {IPriceManager} from "./interfaces/IPriceManager.sol";

contract RecoveryManager is IRecoveryManager, OwnableUpgradeable {
    using EnumerableSet for *;
    using SetHelper for *;
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IPriceManager internal _priceManager;

    uint256 internal _nextStrategyId;

    EnumerableSet.AddressSet internal _whitelistedTokens;
    EnumerableSet.UintSet internal _activeSubscriptionPeriods;

    struct AccountSubscriptionData {
        uint64 startTime;
        uint64 endTime;
    }

    mapping(address => AccountSubscriptionData) internal _accountsSubscription;
    mapping(address => AccountRecoverySettings) internal _accountsRecoverySettings;

    mapping(uint256 => SubscriptionPeriodData) internal _subscriptionPeriodsData;
    mapping(uint256 => StrategyData) internal _strategiesData;

    modifier hasRecoveryMethods() {
        _;
        _hasRecoveryMethods(msg.sender);
    }

    function initialize(address priceManager_) external initializer {
        __Ownable_init(msg.sender);

        _priceManager = IPriceManager(priceManager_);
    }

    function updateWhitelistedTokens(
        address[] calldata tokensToUpdate_,
        bool isAdding_
    ) external onlyOwner {
        if (isAdding_) {
            for (uint256 i = 0; i < tokensToUpdate_.length; i++) {
                require(_priceManager.isTokenSupported(tokensToUpdate_[i]));
            }

            _whitelistedTokens.add(tokensToUpdate_);
        } else {
            _whitelistedTokens.remove(tokensToUpdate_);
        }
    }

    function updateSubscriptionPeriods(
        NewSubscriptionPeriodInfo[] calldata newSubscriptionPeriodsInfo_
    ) external onlyOwner {
        for (uint256 i = 0; i < newSubscriptionPeriodsInfo_.length; i++) {
            NewSubscriptionPeriodInfo calldata currentPeriod_ = newSubscriptionPeriodsInfo_[i];

            _subscriptionPeriodsData[currentPeriod_.duration] = SubscriptionPeriodData({
                strategiesCostFactor: currentPeriod_.strategiesCostFactor
            });

            _activeSubscriptionPeriods.add(currentPeriod_.duration);
        }
    }

    function removeSubscriptionPeriods(uint256[] calldata periodsToRemove_) external onlyOwner {
        _activeSubscriptionPeriods.remove(periodsToRemove_);
    }

    function addRecoveryStrategies(NewStrategyInfo[] calldata newStrategies_) external onlyOwner {
        for (uint256 i = 0; i < newStrategies_.length; i++) {
            require(newStrategies_[i].strategy != address(0));

            _strategiesData[_nextStrategyId++] = StrategyData({
                recoveryCostInUsd: newStrategies_[i].recoveryCostInUsd,
                strategy: newStrategies_[i].strategy,
                status: StrategyStatus.Active
            });
        }
    }

    function disableStrategy(uint256 strategyId_) external onlyOwner {
        require(isActiveStrategy(strategyId_));

        _strategiesData[strategyId_].status = StrategyStatus.Disabled;
    }

    function enableStrategy(uint256 strategyId_) external onlyOwner {
        require(_strategiesData[strategyId_].status == StrategyStatus.Disabled);

        _strategiesData[strategyId_].status = StrategyStatus.Active;
    }

    function withdrawTokens(address tokenAddr_, address recipient_) external onlyOwner {
        if (tokenAddr_ != ETH_ADDR) {
            _transferERC20Tokens(tokenAddr_, address(this), recipient_, type(uint256).max);
        } else {
            Address.sendValue(payable(recipient_), address(this).balance);
        }
    }

    function buyRecoverySubscription(
        address account_,
        uint256 subscriptionDuration_,
        address tokenAddr_
    ) external payable {
        _hasRecoveryMethods(account_);
        require(subscriptionPeriodExists(subscriptionDuration_));
        _priceManager.isTokenSupported(tokenAddr_);

        uint256 amountToPayInUsd_ = getSubscriptionCost(account_, subscriptionDuration_);

        uint256 tokensAmount_ = _priceManager.getAmountFromUsd(tokenAddr_, amountToPayInUsd_);

        if (tokenAddr_ != ETH_ADDR) {
            _transferERC20Tokens(tokenAddr_, msg.sender, address(this), tokensAmount_);
        } else {
            _receiveNative(msg.sender, tokensAmount_);
        }
    }

    function changeRecoverySecurityPercentage(uint256 newRecoverySecurityPercentage_) external {
        _setRecoverySecurityPercentage(msg.sender, newRecoverySecurityPercentage_);
    }

    function changeRecoveryMethod(
        uint256 recoveryMethodId_,
        RecoveryMethod memory newMethodData_
    ) external {
        AccountRecoverySettings storage _recoverySettings = _accountsRecoverySettings[msg.sender];

        _hasActiveRecoveryMethod(msg.sender, recoveryMethodId_);

        _validateRecoveryMethod(newMethodData_);

        _recoverySettings.recoveryMethods[recoveryMethodId_] = newMethodData_;

        emit RecoveryMethodChanged(msg.sender, recoveryMethodId_);
    }

    function removeRecoveryMethods(
        uint256[] calldata methodIdsToRemove_
    ) external hasRecoveryMethods {
        for (uint256 i = 0; i < methodIdsToRemove_.length; i++) {
            _removeRecoveryMethod(msg.sender, methodIdsToRemove_[i]);
        }
    }

    function removeRecoveryMethod(uint256 methodIdToRemove_) external hasRecoveryMethods {
        _removeRecoveryMethod(msg.sender, methodIdToRemove_);
    }

    function subscribe(bytes memory subscribeDataRaw_) external hasRecoveryMethods {
        SubscribeData memory subscribeData_ = abi.decode(subscribeDataRaw_, (SubscribeData));

        _setRecoverySecurityPercentage(msg.sender, subscribeData_.recoverSecurityPercentage);

        for (uint256 i = 0; i < subscribeData_.recoveryMethods.length; i++) {
            _addRecoveryMethod(msg.sender, subscribeData_.recoveryMethods[i]);
        }

        emit AccountSubscribed(msg.sender);
    }

    function unsubscribe() external {
        delete _accountsRecoverySettings[msg.sender];

        emit AccountUnsubscribed(msg.sender);
    }

    function recover(address newOwner_, bytes memory proof_) external {}

    function getRecoveryData(address account_) external view returns (bytes memory) {
        AccountRecoverySettings storage _recoverySettings = _accountsRecoverySettings[account_];

        uint256 activeRecoveryMethodsCount_ = _recoverySettings.activeRecoveryMethodIds.length();

        SubscribeData memory subscribeData_ = SubscribeData({
            recoverSecurityPercentage: _recoverySettings.recoverSecurityPercentage,
            recoveryMethods: new RecoveryMethod[](activeRecoveryMethodsCount_)
        });

        for (uint256 i = 0; i < activeRecoveryMethodsCount_; i++) {
            subscribeData_.recoveryMethods[i] = _recoverySettings.recoveryMethods[
                _recoverySettings.activeRecoveryMethodIds.at(i)
            ];
        }

        return abi.encode(subscribeData_);
    }

    function getSubscriptionCost(
        address account_,
        uint256 subscriptionDuration_
    ) public view returns (uint256) {
        if (!subscriptionPeriodExists(subscriptionDuration_)) {
            return 0;
        }

        return
            Math.mulDiv(
                getBaseSubscriptionCost(account_),
                _subscriptionPeriodsData[subscriptionDuration_].strategiesCostFactor,
                PERCENTAGE_100
            );
    }

    function getBaseSubscriptionCost(address account_) public view returns (uint256 totalCost_) {
        AccountRecoverySettings storage _recoverySettings = _accountsRecoverySettings[account_];

        uint256 recoveryMethodsCount_ = getAccountRecoveryMethodsCount(account_);

        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            uint256 recoveryMethodId_ = _recoverySettings.activeRecoveryMethodIds.at(i);

            totalCost_ += getStrategyRecoveryCostInUsd(
                _recoverySettings.recoveryMethods[recoveryMethodId_].strategyId
            );
        }
    }

    function getStrategyRecoveryCostInUsd(uint256 strategyId_) public view returns (uint256) {
        return _strategiesData[strategyId_].recoveryCostInUsd;
    }

    function getAccountRecoveryMethodsCount(address account_) public view returns (uint256) {
        return _accountsRecoverySettings[account_].activeRecoveryMethodIds.length();
    }

    function subscriptionPeriodExists(uint256 duration_) public view returns (bool) {
        return _activeSubscriptionPeriods.contains(duration_);
    }

    function isActiveStrategy(uint256 strategyId_) public view returns (bool) {
        return _strategiesData[strategyId_].status == StrategyStatus.Active;
    }

    function isActiveRecoveryMethod(
        address account_,
        uint256 recoveryMethodId_
    ) public view returns (bool) {
        return
            _accountsRecoverySettings[account_].activeRecoveryMethodIds.contains(
                recoveryMethodId_
            );
    }

    function _setRecoverySecurityPercentage(
        address account_,
        uint256 newRecoverySecurityPercentage_
    ) internal {
        require(
            newRecoverySecurityPercentage_ > 0 && newRecoverySecurityPercentage_ <= PERCENTAGE_100
        );

        _accountsRecoverySettings[account_]
            .recoverSecurityPercentage = newRecoverySecurityPercentage_;

        emit RecoverySecurityPercentageChanged(account_, newRecoverySecurityPercentage_);
    }

    function _addRecoveryMethod(address account_, RecoveryMethod memory recoveryMethod_) internal {
        _validateRecoveryMethod(recoveryMethod_);

        AccountRecoverySettings storage _recoverySettings = _accountsRecoverySettings[account_];

        uint256 newMethodId_ = _recoverySettings.nextRecoveryMethodId++;

        _recoverySettings.activeRecoveryMethodIds.add(newMethodId_);
        _recoverySettings.recoveryMethods[newMethodId_] = recoveryMethod_;

        emit NewRecoveryMethodAdded(account_, newMethodId_);
    }

    function _removeRecoveryMethod(address account_, uint256 methodId_) internal {
        AccountRecoverySettings storage _recoverySettings = _accountsRecoverySettings[account_];

        _hasActiveRecoveryMethod(account_, methodId_);

        _recoverySettings.activeRecoveryMethodIds.remove(methodId_);
        delete _recoverySettings.recoveryMethods[methodId_];

        emit RecoveryMethodRemoved(account_, methodId_);
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
        require(isActiveStrategy(recoveryMethod_.strategyId));

        IRecoveryStrategy(_strategiesData[recoveryMethod_.strategyId].strategy)
            .validateAccountRecoveryData(recoveryMethod_.recoveryData);
    }

    function _hasActiveRecoveryMethod(address account_, uint256 recoveryMethodId_) internal view {
        require(isActiveRecoveryMethod(account_, recoveryMethodId_));
    }

    function _hasRecoveryMethods(address account_) internal view {
        require(_accountsRecoverySettings[account_].activeRecoveryMethodIds.length() > 0);
    }
}
