// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISignatureSubscriptionModule {
    event SubscriptionSignerUpdated(address indexed newSubscriptionSigner);
    event SubscriptionBoughtWithSignature(address indexed sender, uint64 duration, uint256 nonce);

    function setSubscriptionSigner(address newSubscriptionSigner_) external;
    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external;
    function getSubscriptionSigner() external view returns (address);
    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) external view returns (bytes32);
}
