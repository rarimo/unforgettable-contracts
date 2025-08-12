// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISBTSubscriptionModule {
    struct SBTTokenUpdateEntry {
        address sbtToken;
        uint64 subscriptionTimePerToken;
    }

    error NotSupportedSBT(address tokenAddr);
    error NotATokenOwner(address tokenAddr, address userAddr, uint256 tokenId);

    event SubscriptionBoughtWithSBT(
        address indexed sbtToken,
        address indexed sender,
        uint256 tokenId
    );
    event SBTTokenUpdated(address indexed sbtToken, uint64 subscriptionTimePerToken);

    function updateSBTTokens(SBTTokenUpdateEntry[] calldata sbtTokenEntries_) external;
    function buySubscriptionWithSBT(
        address account_,
        address sbtTokenAddr_,
        uint256 tokenId_
    ) external;
    function isSupportedSBT(address sbtToken_) external view returns (bool);
    function getSubscriptionTimePerSBT(address sbtToken_) external view returns (uint64);
}
