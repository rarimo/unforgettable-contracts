// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VaultFactory} from "../../vaults/VaultFactory.sol";
import {IVaultSubscriptionManager} from "../../interfaces/vaults/IVaultSubscriptionManager.sol";

contract VaultFactoryMock is VaultFactory {
    function setVaultName(address vault_, string memory vaultName_) external {
        _setVaultName(vault_, vaultName_);
    }

    function callBuySubscriptionWithSBT(
        address subscriptionManagerAddr_,
        address vault_,
        address sbt_,
        address sbtOwner_,
        uint256 tokenId_
    ) external {
        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            subscriptionManagerAddr_
        );

        subscriptionManager_.buySubscriptionWithSBT(vault_, sbt_, sbtOwner_, tokenId_);
    }

    function callBuySubscriptionWithSignature(
        address subscriptionManagerAddr_,
        address sender_,
        address vault_,
        uint64 duration_,
        bytes memory signature_
    ) external {
        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            subscriptionManagerAddr_
        );

        subscriptionManager_.buySubscriptionWithSignature(sender_, vault_, duration_, signature_);
    }

    function version() external pure returns (string memory) {
        return "v2.0.0";
    }
}
