// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionManager} from "../core/ISubscriptionManager.sol";

interface IVaultSubscriptionManager is ISubscriptionManager {
    struct VaultSubscriptionManagerInitData {
        address vaultFactoryAddr;
        address[] subscriptionCreators;
        TokensPaymentModuleInitData tokensPaymentInitData;
        SBTPaymentModuleInitData sbtPaymentInitData;
        SigSubscriptionModuleInitData sigSubscriptionInitData;
        CrossChainModuleInitData crossChainInitData;
    }

    error NotAVault(address vaultAddr);
    error NotAVaultFactory(address vaultAddr);
    error InactiveVaultSubscription(address account);

    event VaultFactoryUpdated(address vaultFactory);

    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        address sbtOwner_,
        uint256 tokenId_
    ) external;

    function buySubscriptionWithSignature(
        address sender_,
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) external;

    function getVaultFactory() external view returns (address);
}
