// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISubscriptionManager {
    event SubscriptionExtended(address indexed account, uint64 duration, uint64 newEndTime);

    function buySubscription(address account_, address token_, uint64 duration_) external payable;

    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external;

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external;

    function getSubscriptionCost(
        address account_,
        address token_,
        uint64 duration_
    ) external view returns (uint256 totalCost_);

    function getAccountSubscriptionEndTime(address account_) external view returns (uint64);

    function isAvailableForPayment(address token_) external view returns (bool);

    function hasActiveSubscription(address account_) external view returns (bool);

    function hasSubscriptionDebt(address account_) external view returns (bool);
}
