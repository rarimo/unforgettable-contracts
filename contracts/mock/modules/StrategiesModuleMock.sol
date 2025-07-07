// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategiesModule} from "../../modules/StrategiesModule.sol";

contract StrategiesModuleMock is StrategiesModule {
    function addStrategy(address strategy_, uint256 baseRecoveryCostInUsd_) external {
        _addStrategy(strategy_, baseRecoveryCostInUsd_);
    }

    function disableStrategy(uint256 strategyId_) external {
        _disableStrategy(strategyId_);
    }

    function enableStrategy(uint256 strategyId_) external {
        _enableStrategy(strategyId_);
    }
}
