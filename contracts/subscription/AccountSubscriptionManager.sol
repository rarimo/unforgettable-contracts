// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {SBTSubscriptionModule} from "./modules/SBTSubscriptionModule.sol";

contract AccountSubscriptionManager is SignatureSubscriptionModule, SBTSubscriptionModule {
    function initialize(
        uint64 basePeriodDuration_,
        address subscriptionSigner_,
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_,
        SBTTokenUpdateEntry[] calldata sbtTokenEntries_
    ) external initializer {
        __BaseSubscriptionManager_init(basePeriodDuration_, paymentTokenEntries_);

        __SignatureSubscriptionModule_init(subscriptionSigner_);

        __SBTSubscriptionModule_init(sbtTokenEntries_);
    }
}
