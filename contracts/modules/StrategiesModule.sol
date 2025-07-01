// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategiesModule} from "../interfaces/modules/IStrategiesModule.sol";

contract StrategiesModule is IStrategiesModule {
    bytes32 public constant STRATEGIES_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.strategies.module.storage");

    struct StrategiesModuleStorage {
        uint256 nextStrategyId;
        mapping(uint256 => StrategyData) strategiesData;
    }

    function _getStrategiesModuleStorage()
        private
        pure
        returns (StrategiesModuleStorage storage _sms)
    {
        bytes32 slot_ = STRATEGIES_MODULE_STORAGE_SLOT;

        assembly {
            _sms.slot := slot_
        }
    }

    function getNextStrategyId() external view returns (uint256) {
        return _getStrategiesModuleStorage().nextStrategyId;
    }

    function getStrategyData(uint256 strategyId_) external view returns (StrategyData memory) {
        return _getStrategiesModuleStorage().strategiesData[strategyId_];
    }

    function getRecoveryCostInUsdByPeriods(
        uint256 strategyId_,
        uint256 periodsCount_
    ) public view returns (uint256) {
        return getBaseRecoveryCostInUsd(strategyId_) * periodsCount_;
    }

    function getBaseRecoveryCostInUsd(uint256 strategyId_) public view returns (uint256) {
        return _getStrategiesModuleStorage().strategiesData[strategyId_].baseRecoveryCostInUsd;
    }

    function getStrategyStatus(uint256 strategyId_) public view returns (StrategyStatus) {
        return _getStrategiesModuleStorage().strategiesData[strategyId_].status;
    }

    function getStrategy(uint256 strategyId_) public view returns (address) {
        return _getStrategiesModuleStorage().strategiesData[strategyId_].strategy;
    }

    function isActiveStrategy(uint256 strategyId_) public view returns (bool) {
        return getStrategyStatus(strategyId_) == StrategyStatus.Active;
    }

    function _addStrategy(address strategy_, uint256 baseRecoveryCostInUsd_) internal {
        StrategiesModuleStorage storage $ = _getStrategiesModuleStorage();

        require(strategy_ != address(0), ZeroStrategyAddress());

        uint256 strategyId_ = $.nextStrategyId++;
        $.strategiesData[strategyId_] = StrategyData({
            baseRecoveryCostInUsd: baseRecoveryCostInUsd_,
            strategy: strategy_,
            status: StrategyStatus.Active
        });

        emit StrategyAdded(strategyId_);
    }

    function _disableStrategy(uint256 strategyId_) internal {
        _hasStrategyStatus(strategyId_, StrategyStatus.Active);

        _getStrategiesModuleStorage().strategiesData[strategyId_].status = StrategyStatus.Disabled;

        emit StrategyDisabled(strategyId_);
    }

    function _enableStrategy(uint256 strategyId_) internal {
        _hasStrategyStatus(strategyId_, StrategyStatus.Disabled);

        _getStrategiesModuleStorage().strategiesData[strategyId_].status = StrategyStatus.Active;

        emit StrategyEnabled(strategyId_);
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
}
