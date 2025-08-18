// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

interface ISBTPaymentModule is IBaseSubscriptionModule {
    struct SBTUpdateEntry {
        address sbt;
        uint64 subscriptionDurationPerToken;
    }

    struct SBTPaymentModuleInitData {
        SBTUpdateEntry[] sbtEntries;
    }

    error NotSupportedSBT(address sbt);
    error SBTAlreadyAdded(address sbt);
    error NotASBTOwner(address sbt, address userAddr, uint256 tokenId);

    event SBTAdded(address indexed sbt);
    event SBTRemoved(address indexed sbt);
    event SubscriptionDurationPerSBTUpdated(address indexed sbt, uint64 newDuration);
    event SubscriptionBoughtWithSBT(address indexed sbt, address indexed sender, uint256 tokenId);

    function buySubscriptionWithSBT(address account_, address sbt_, uint256 tokenId_) external;

    function isSupportedSBT(address sbtToken_) external view returns (bool);

    function getSubscriptionTimePerSBT(address sbtToken_) external view returns (uint64);
}
