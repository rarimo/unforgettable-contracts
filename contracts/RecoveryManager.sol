// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IRecoveryManager} from "./interfaces/IRecoveryManager.sol";
import {ISubscriptionManager} from "./interfaces/vaults/ISubscriptionManager.sol";
import {IRecoveryStrategy} from "./interfaces/strategies/IRecoveryStrategy.sol";

contract RecoveryManager is IRecoveryManager, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant RECOVERY_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.recovery.manager.storage");

    struct SubscribeData {
        address subscriptionManager;
        address paymentTokenAddr;
        uint64 duration;
        RecoveryMethod recoveryMethod;
    }

    struct RecoveryMethod {
        uint256 strategyId;
        bytes recoveryData;
    }

    struct AccountRecoveryData {
        address subscriptionManager;
        RecoveryMethod recoveryMethod;
    }

    struct RecoveryManagerStorage {
        uint256 nextStrategyId;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint256 => StrategyData) strategiesData;
        mapping(address => AccountRecoveryData) accountsRecoveryData;
    }

    struct RecoveryData {
        bytes accountRecoveryData;
        bytes recoveryProof;
    }

    error InvalidRecoveryStrategy(address recoveryStrategy);
    error SubscriptionManagerDoesNotExist(address subscriptionManager);
    error NoActiveSubscription(address subscriptionManager, address account);

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
    ) external initializer {
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

    function subscribe(bytes memory recoveryData_) external {
        // Make payable?
        RecoveryManagerStorage storage $ = _getRecoveryManagerStorage();

        SubscribeData memory subscribeData_ = abi.decode(recoveryData_, (SubscribeData));

        _onlyExistingSubscriptionManager(subscribeData_.subscriptionManager);

        _validateRecoveryMethod(subscribeData_.recoveryMethod);

        if (subscribeData_.paymentTokenAddr != address(0)) {
            _buySubscriptionFor(
                msg.sender,
                ISubscriptionManager(subscribeData_.subscriptionManager),
                IERC20(subscribeData_.paymentTokenAddr),
                subscribeData_.duration
            );
        }

        require(
            ISubscriptionManager(subscribeData_.subscriptionManager).hasActiveSubscription(
                msg.sender
            ),
            NoActiveSubscription(subscribeData_.subscriptionManager, msg.sender)
        );

        $.accountsRecoveryData[msg.sender].subscriptionManager = subscribeData_
            .subscriptionManager;
        $.accountsRecoveryData[msg.sender].recoveryMethod = subscribeData_.recoveryMethod;

        emit AccountSubscribed(msg.sender);
    }

    function unsubscribe() external {
        delete _getRecoveryManagerStorage().accountsRecoveryData[msg.sender];

        emit AccountUnsubscribed(msg.sender);
    }

    function recover(address newOwner_, bytes memory proof_) external {
        RecoveryMethod memory recoveryMethod_ = _getRecoveryManagerStorage()
            .accountsRecoveryData[msg.sender]
            .recoveryMethod;

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).recoverAccount(
            msg.sender,
            newOwner_,
            abi.encode(
                RecoveryData({
                    accountRecoveryData: recoveryMethod_.recoveryData,
                    recoveryProof: proof_
                })
            )
        );
    }

    function getRecoveryData(address account_) external view returns (bytes memory) {
        return abi.encode(_getRecoveryManagerStorage().accountsRecoveryData[account_]);
    }

    function getSubscribeCost(
        bytes memory recoveryData_
    ) external view returns (uint256, address) {
        SubscribeData memory subscribeData_ = abi.decode(recoveryData_, (SubscribeData));

        uint256 subscriptionCost_ = ISubscriptionManager(subscribeData_.subscriptionManager)
            .getSubscriptionCost(
                msg.sender,
                subscribeData_.paymentTokenAddr,
                subscribeData_.duration
            );

        return (subscriptionCost_, subscribeData_.paymentTokenAddr);
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

    function _buySubscriptionFor(
        address account_,
        ISubscriptionManager subscriptionManager_,
        IERC20 paymentToken_,
        uint64 duration_
    ) internal {
        uint256 subscriptionCostInTokens_ = subscriptionManager_.getSubscriptionCost(
            account_,
            address(paymentToken_),
            duration_
        );

        paymentToken_.safeTransferFrom(account_, address(this), subscriptionCostInTokens_);
        paymentToken_.approve(address(subscriptionManager_), subscriptionCostInTokens_);

        subscriptionManager_.buySubscription(account_, address(paymentToken_), duration_);
    }

    function _validateRecoveryMethod(RecoveryMethod memory recoveryMethod_) internal view {
        _hasStrategyStatus(recoveryMethod_.strategyId, StrategyStatus.Active);

        IRecoveryStrategy(getStrategy(recoveryMethod_.strategyId)).validateAccountRecoveryData(
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
