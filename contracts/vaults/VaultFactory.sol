// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVault} from "../interfaces/vaults/IVault.sol";

/**
 * @title VaultFactory
 * @notice Factory contract for deploying Vault instances using CREATE2
 */
contract VaultFactory is OwnableUpgradeable, UUPSUpgradeable, NoncesUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant VAULT_FACTORY_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.factory.storage");

    struct VaultFactoryStorage {
        address vaultImplementation;
        address vaultSubscriptionManager;
        address recoveryManager;
        mapping(address => uint256) tokensLimitAmounts;
        mapping(address => bool) deployedVaults;
    }

    error ZeroAddress();

    event VaultImplementationUpdated(address newVaultImplementation);
    event TokenLimitAmountUpdated(address indexed tokenAddr, uint256 newLimitAmount);
    event VaultDeployed(address indexed owner, address indexed vault);

    function _getVaultFactoryStorage() private pure returns (VaultFactoryStorage storage _vfs) {
        bytes32 slot_ = VAULT_FACTORY_STORAGE_SLOT;

        assembly {
            _vfs.slot := slot_
        }
    }

    function initialize(
        address vaultImplementation_,
        address vaultSubscriptionManager_,
        address recoveryManager_,
        address initialOwner_
    ) external initializer {
        __Ownable_init(initialOwner_);

        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        _updateVaultImplementation(vaultImplementation_);

        $.vaultSubscriptionManager = vaultSubscriptionManager_;
        $.recoveryManager = recoveryManager_;
    }

    function updateVaultImplementation(address newVaultImpl_) external onlyOwner {
        _updateVaultImplementation(newVaultImpl_);
    }

    function updateTokenLimitAmount(address token_, uint256 newLimitAmount_) external onlyOwner {
        _updateTokenLimitAmount(token_, newLimitAmount_);
    }

    function deployVault(
        address paymentToken_,
        uint256 initialSubscriptionDuration_,
        uint64 recoveryTimelock_,
        uint64 recoveryDelay_,
        bytes memory recoveryData_
    ) external returns (address vaultAddr_) {
        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        address owner_ = _msgSender();
        bytes32 salt_ = keccak256(abi.encodePacked(owner_, _useNonce(owner_)));

        vaultAddr_ = _deploy2($.vaultImplementation, salt_);

        IVault(vaultAddr_).initialize(
            IVault.VaultInitParams({
                vaultOwner: owner_,
                paymentToken: paymentToken_,
                initialSubscriptionDuration: initialSubscriptionDuration_,
                recoveryTimelock: recoveryTimelock_,
                recoveryDelay: recoveryDelay_,
                recoveryData: recoveryData_
            })
        );

        $.deployedVaults[vaultAddr_] = true;

        emit VaultDeployed(owner_, vaultAddr_);
    }

    function isVault(address vaultAddr_) external view returns (bool) {
        return _getVaultFactoryStorage().deployedVaults[vaultAddr_];
    }

    function getTokenLimitAmount(address token_) external view returns (uint256) {
        return _getVaultFactoryStorage().tokensLimitAmounts[token_];
    }

    function getVaultSubscriptionManager() external view returns (address) {
        return _getVaultFactoryStorage().vaultSubscriptionManager;
    }

    function getRecoveryManager() external view returns (address) {
        return _getVaultFactoryStorage().vaultSubscriptionManager;
    }

    function _updateVaultImplementation(address newVaultImpl_) internal {
        require(newVaultImpl_ != address(0), ZeroAddress());

        _getVaultFactoryStorage().vaultImplementation = newVaultImpl_;

        emit VaultImplementationUpdated(newVaultImpl_);
    }

    function _updateTokenLimitAmount(address token_, uint256 newLimitAmount_) internal {
        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        $.tokensLimitAmounts[token_] = newLimitAmount_;

        emit TokenLimitAmountUpdated(token_, newLimitAmount_);
    }

    function _deploy2(address implementation_, bytes32 salt_) internal returns (address payable) {
        return payable(address(new ERC1967Proxy{salt: salt_}(implementation_, new bytes(0))));
    }

    /**
     * @notice Authorize upgrade (UUPS pattern)
     * @param newImplementation_ The new implementation address
     * @dev Only callable by factory owner
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}
}
