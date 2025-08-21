// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TokensPaymentModule} from "../../../../core/subscription/modules/TokensPaymentModule.sol";

contract TokensPaymentModuleMock is TokensPaymentModule {
    function initialize(TokensPaymentModuleInitData calldata initData_) external initializer {
        __TokensPaymentModule_init(initData_);
    }

    function setBasePaymentPeriod(uint64 newBasePaymentPeriod_) external {
        _setBasePaymentPeriod(newBasePaymentPeriod_);
    }

    function updateDurationFactor(uint64 duration_, uint256 factor_) external {
        _updateDurationFactor(duration_, factor_);
    }

    function withdrawTokens(address tokenAddr_, address to_, uint256 amount_) external {
        _withdrawTokens(tokenAddr_, to_, amount_);
    }

    function updatePaymentToken(address paymentToken_, uint256 baseSubscriptionCost_) external {
        _updatePaymentToken(paymentToken_, baseSubscriptionCost_);
    }

    function addPaymentToken(address paymentToken_) external {
        _addPaymentToken(paymentToken_);
    }

    function removePaymentToken(address paymentToken_) external {
        _removePaymentToken(paymentToken_);
    }
}
