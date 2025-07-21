// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VaultFactory} from "../../vaults/VaultFactory.sol";

contract VaultFactoryMock is VaultFactory {
    function setDeployedVault(address vault_, bool deployed_) external {
        _getVaultFactoryStorageMock().deployedVaults[vault_] = deployed_;
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
