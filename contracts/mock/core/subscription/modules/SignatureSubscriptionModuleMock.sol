// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureSubscriptionModule} from "../../../../core/subscription/modules/SignatureSubscriptionModule.sol";

contract SignatureSubscriptionModuleMock is SignatureSubscriptionModule {
    function initialize(SigSubscriptionModuleInitData calldata initData_) external initializer {
        __SignatureSubscriptionModule_init(initData_);
    }

    function setSubscriptionSigner(address newSigner_) external {
        _setSubscriptionSigner(newSigner_);
    }
}
