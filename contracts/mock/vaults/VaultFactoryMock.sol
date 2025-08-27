// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VaultFactory} from "../../vaults/VaultFactory.sol";
import {IVaultSubscriptionManager} from "../../interfaces/vaults/IVaultSubscriptionManager.sol";

contract VaultFactoryMock is VaultFactory {
    function setDeployedVault(address vault_, bool deployed_) external {
        _getVaultFactoryStorageMock().deployedVaults[vault_] = deployed_;
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

    function _getVaultFactoryStorageMock()
        private
        pure
        returns (VaultFactoryStorage storage _vfs)
    {
        bytes32 slot_ = VAULT_FACTORY_STORAGE_SLOT;

        assembly {
            _vfs.slot := slot_
        }
    }
}
