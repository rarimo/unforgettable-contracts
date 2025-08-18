// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {IRecoveryManager} from "../interfaces/core/IRecoveryManager.sol";
import {ISubscriptionManager} from "../interfaces/core/ISubscriptionManager.sol";
import {IRecoveryStrategy} from "../interfaces/core/strategies/IRecoveryStrategy.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";

contract RecoveryManager is IRecoveryManager, ADeployerGuard, OwnableUpgradeable {
    using EnumerableSet for *;
    using TokensHelper for address;

    bytes32 public constant RECOVERY_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.recovery.manager.storage");

    struct RecoveryManagerStorage {
        uint256 nextStrategyId;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint256 => StrategyData) strategiesData;
        mapping(address => AccountRecoveryData) accountsRecoveryData;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
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

    function initialize(
        address[] calldata subscriptionManagers_,
        address[] calldata recoveryStrategies_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateSubscriptionManagers(subscriptionManagers_, true);
        _addStrategies(recoveryStrategies_);
    }

    function updateSubscriptionManagers(
        address[] calldata subscriptionManagersToUpdate_,
        bool isAdding_
    ) external onlyOwner {
        _updateSubscriptionManagers(subscriptionManagersToUpdate_, isAdding_);
    }

    function addRecoveryStrategies(address[] calldata newStrategies_) external onlyOwner {
        _addStrategies(newStrategies_);
    }

    function disableStrategy(uint256 strategyId_) external onlyOwner {
        _disableStrategy(strategyId_);
    }

    function enableStrategy(uint256 strategyId_) external onlyOwner {
        _enableStrategy(strategyId_);
    }

    function subscribe(bytes memory recoveryData_) external payable {
        _subscribe(recoveryData_);
    }

    function unsubscribe() external payable {
        _unsubscribe();
    }

    function resubscribe(bytes memory recoveryData_) external payable {
        _unsubscribe();

        _subscribe(recoveryData_);
    }

    function recover(bytes memory object_, bytes memory proof_) external {
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        (
            address subscriptionManager_,
            uint256 recoveryMethodId_,
            bytes memory recoveryProof_
        ) = abi.decode(proof_, (address, uint256, bytes));

        _onlyExistingSubscriptionManager(subscriptionManager_);

        _checkActiveSubscription(subscriptionManager_, msg.sender);

        AccountRecoveryData storage recoveryData = $.accountsRecoveryData[msg.sender];

        require(
            recoveryData.activeRecoveryMethods.contains(recoveryMethodId_),
            RecoveryMethodNotSet(msg.sender, recoveryMethodId_)
        );

        RecoveryMethod memory recoveryMethod_ = recoveryData.recoveryMethods[recoveryMethodId_];

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).recoverAccount(
            msg.sender,
            object_,
            abi.encode(recoveryMethod_.recoveryData, recoveryProof_)
        );
    }

    function getRecoveryData(address account_) external view returns (bytes memory) {
        return abi.encode(getRecoveryMethods(account_));
    }

    function getRecoveryMethods(
        address account_
    ) public view returns (RecoveryMethod[] memory recoveryMethods_) {
        AccountRecoveryData storage recoveryData = _getRecoveryManagerStorage()
            .accountsRecoveryData[account_];

        uint256[] memory recoveryMethodIds_ = recoveryData.activeRecoveryMethods.values();

        uint256 recoveryMethodsCount_ = recoveryMethodIds_.length;

        recoveryMethods_ = new RecoveryMethod[](recoveryMethodsCount_);

        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            recoveryMethods_[i] = recoveryData.recoveryMethods[recoveryMethodIds_[i]];
        }
    }

    function subscriptionManagerExists(address subscriptionManager_) public view returns (bool) {
        return _getRecoveryManagerStorage().subscriptionManagers.contains(subscriptionManager_);
    }

    function getStrategyStatus(uint256 strategyId_) public view returns (StrategyStatus) {
        return _getRecoveryManagerStorage().strategiesData[strategyId_].status;
    }

    function getStrategy(uint256 strategyId_) public view returns (address) {
        return _getRecoveryManagerStorage().strategiesData[strategyId_].strategy;
    }

    function isActiveStrategy(uint256 strategyId_) public view returns (bool) {
        return getStrategyStatus(strategyId_) == StrategyStatus.Active;
    }

    function _updateSubscriptionManagers(
        address[] calldata subscriptionManagersToUpdate_,
        bool isAdding_
    ) internal {
        if (isAdding_) {
            _addSubscriptionManagers(subscriptionManagersToUpdate_);
        } else {
            _removeSubscriptionManagers(subscriptionManagersToUpdate_);
        }
    }

    function _addSubscriptionManagers(address[] memory newSubscriptionManagers_) internal {
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        for (uint256 i = 0; i < newSubscriptionManagers_.length; i++) {
            $.subscriptionManagers.add(newSubscriptionManagers_[i]);

            emit SubscriptionManagerAdded(newSubscriptionManagers_[i]);
        }
    }

    function _removeSubscriptionManagers(address[] memory subscriptionManagersToRemove_) internal {
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        for (uint256 i = 0; i < subscriptionManagersToRemove_.length; i++) {
            $.subscriptionManagers.remove(subscriptionManagersToRemove_[i]);

            emit SubscriptionManagerRemoved(subscriptionManagersToRemove_[i]);
        }
    }

    function _addStrategies(address[] memory strategies_) internal {
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        uint256 firstNewStrategyId_ = $.nextStrategyId;
        for (uint256 i = 0; i < strategies_.length; i++) {
            require(strategies_[i] != address(0), ZeroStrategyAddress());
            require(
                IRecoveryStrategy(strategies_[i]).getRecoveryManager() == address(this),
                InvalidRecoveryStrategy(strategies_[i])
            );

            uint256 newStrategyId_ = firstNewStrategyId_ + i;
            $.strategiesData[newStrategyId_] = StrategyData({
                strategy: strategies_[i],
                status: StrategyStatus.Active
            });

            emit StrategyAdded(newStrategyId_);
        }

        $.nextStrategyId = firstNewStrategyId_ + strategies_.length;
    }

    function _disableStrategy(uint256 strategyId_) internal {
        _hasStrategyStatus(strategyId_, StrategyStatus.Active);

        _getRecoveryManagerStorage().strategiesData[strategyId_].status = StrategyStatus.Disabled;

        emit StrategyDisabled(strategyId_);
    }

    function _enableStrategy(uint256 strategyId_) internal {
        _hasStrategyStatus(strategyId_, StrategyStatus.Disabled);

        _getRecoveryManagerStorage().strategiesData[strategyId_].status = StrategyStatus.Active;

        emit StrategyEnabled(strategyId_);
    }

    function _subscribe(bytes memory recoveryData_) internal {
        AccountRecoveryData storage recoveryData = _getRecoveryManagerStorage()
            .accountsRecoveryData[msg.sender];

        require(recoveryData.nextRecoveryMethodId == 0, AccountAlreadySubscribed(msg.sender));

        SubscribeData memory subscribeData_ = abi.decode(recoveryData_, (SubscribeData));

        _onlyExistingSubscriptionManager(subscribeData_.subscriptionManager);

        uint256 recoveryMethodsCount_ = subscribeData_.recoveryMethods.length;

        require(recoveryMethodsCount_ > 0, NoRecoveryMethodsProvided());

        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            _validateRecoveryMethod(subscribeData_.recoveryMethods[i]);
        }

        ISubscriptionManager subscriptionManager_ = ISubscriptionManager(
            subscribeData_.subscriptionManager
        );

        if (!subscriptionManager_.hasSubscription(msg.sender)) {
            subscriptionManager_.activateSubscription(msg.sender);
        }

        if (subscribeData_.paymentTokenAddr != address(0)) {
            _buySubscriptionFor(
                msg.sender,
                subscriptionManager_,
                subscribeData_.paymentTokenAddr,
                subscribeData_.duration
            );
        }

        uint256 firstRecoveryMethodId_ = recoveryData.nextRecoveryMethodId;
        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            uint256 newRecoveryMethodId_ = firstRecoveryMethodId_ + i;

            recoveryData.activeRecoveryMethods.add(newRecoveryMethodId_);

            recoveryData.recoveryMethods[newRecoveryMethodId_] = subscribeData_.recoveryMethods[i];
        }

        recoveryData.nextRecoveryMethodId = firstRecoveryMethodId_ + recoveryMethodsCount_;

        emit AccountSubscribed(msg.sender);
    }

    function _unsubscribe() internal {
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        AccountRecoveryData storage recoveryData = $.accountsRecoveryData[msg.sender];

        require(recoveryData.nextRecoveryMethodId != 0, AccountNotSubscribed(msg.sender));

        recoveryData.activeRecoveryMethods.clear();

        delete $.accountsRecoveryData[msg.sender];

        emit AccountUnsubscribed(msg.sender);
    }

    function _buySubscriptionFor(
        address account_,
        ISubscriptionManager subscriptionManager_,
        address paymentToken_,
        uint64 duration_
    ) internal {
        uint256 subscriptionCostInTokens_ = subscriptionManager_.getSubscriptionCost(
            account_,
            paymentToken_,
            duration_
        );

        paymentToken_.receiveTokens(msg.sender, subscriptionCostInTokens_);

        uint256 valueAmount_;

        if (paymentToken_.isNativeToken()) {
            valueAmount_ = subscriptionCostInTokens_;
        } else {
            IERC20(paymentToken_).approve(
                address(subscriptionManager_),
                subscriptionCostInTokens_
            );
        }

        subscriptionManager_.buySubscription{value: valueAmount_}(
            account_,
            address(paymentToken_),
            duration_
        );
    }

    function _checkActiveSubscription(
        address subscriptionManager_,
        address account_
    ) internal view {
        require(
            ISubscriptionManager(subscriptionManager_).hasActiveSubscription(account_),
            NoActiveSubscription(subscriptionManager_, account_)
        );
    }

    function _validateRecoveryMethod(RecoveryMethod memory recoveryMethod_) internal view {
        _hasStrategyStatus(recoveryMethod_.strategyId, StrategyStatus.Active);

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).validateRecoveryData(
            recoveryMethod_.recoveryData
        );
    }

    function _hasStrategyStatus(
        uint256 strategyId_,
        StrategyStatus requiredStatus_
    ) internal view {
        StrategyStatus currentStatus_ = getStrategyStatus(strategyId_);

        require(
            currentStatus_ == requiredStatus_,
            InvalidStrategyStatus(requiredStatus_, currentStatus_)
        );
    }

    function _onlyExistingSubscriptionManager(address subscriptionManager_) internal view {
        require(
            subscriptionManagerExists(subscriptionManager_),
            SubscriptionManagerDoesNotExist(subscriptionManager_)
        );
    }
}
