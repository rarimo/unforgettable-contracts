// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SBTPaymentModule} from "../../../../core/subscription/modules/SBTPaymentModule.sol";

contract SBTPaymentModuleMock is SBTPaymentModule {
    function initialize(SBTPaymentModuleInitData calldata initData_) external initializer {
        __SBTPaymentModule_init(initData_);
    }

    function updateSBT(address sbt_, uint64 newDurationPerToken_) external {
        _updateSBT(sbt_, newDurationPerToken_);
    }

    function addSBT(address sbt_) external {
        _addSBT(sbt_);
    }

    function removeSBT(address sbt_) external {
        _removeSBT(sbt_);
    }
}
