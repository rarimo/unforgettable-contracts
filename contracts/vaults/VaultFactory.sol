// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Paginator} from "@solarity/solidity-lib/libs/arrays/Paginator.sol";
import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {CREATE3} from "solady/src/utils/CREATE3.sol";

import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";

/**
 * @title VaultFactory
 * @notice Factory contract for deploying Vault instances using CREATE2
 */
contract VaultFactory is
    IVaultFactory,
    ADeployerGuard,
    OwnableUpgradeable,
    UUPSUpgradeable,
    NoncesUpgradeable,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Paginator for EnumerableSet.AddressSet;
    using TokensHelper for address;

    bytes32 public constant VAULT_FACTORY_STORAGE_SLOT =
        keccak256("unforgettable.contract.vault.factory.storage");

    uint256 public constant MIN_VAULT_NAME_LENGTH = 6;

    struct VaultFactoryStorage {
        address vaultImplementation;
        address vaultSubscriptionManager;
        mapping(address => uint256) tokensLimitAmounts;
        mapping(address => string) vaultNames;
        mapping(bytes32 => address) namesToVaults;
        mapping(address => EnumerableSet.AddressSet) vaultsByCreator;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getVaultFactoryStorage() private pure returns (VaultFactoryStorage storage _vfs) {
        bytes32 slot_ = VAULT_FACTORY_STORAGE_SLOT;

        assembly {
            _vfs.slot := slot_
        }
    }

    function initialize(
        address vaultImplementation_,
        address vaultSubscriptionManager_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _getVaultFactoryStorage().vaultSubscriptionManager = vaultSubscriptionManager_;

        _updateVaultImplementation(vaultImplementation_);
    }

    /// @inheritdoc IVaultFactory
    function updateVaultImplementation(address newVaultImpl_) external onlyOwner {
        _updateVaultImplementation(newVaultImpl_);
    }

    /// @inheritdoc IVaultFactory
    function updateTokenLimitAmount(address token_, uint256 newLimitAmount_) external onlyOwner {
        _updateTokenLimitAmount(token_, newLimitAmount_);
    }

    /// @inheritdoc IVaultFactory
    function deployVault(
        address masterKey_,
        address paymentToken_,
        uint64 initialSubscriptionDuration_,
        string memory vaultName_
    ) external payable nonReentrant returns (address vaultAddr_) {
        vaultAddr_ = _deployVault(masterKey_, vaultName_);

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            _getVaultFactoryStorage().vaultSubscriptionManager
        );

        uint256 subscriptionCost_ = subscriptionManager_.getSubscriptionCost(
            vaultAddr_,
            paymentToken_,
            initialSubscriptionDuration_
        );

        paymentToken_.receiveTokens(msg.sender, subscriptionCost_);

        uint256 subscriptionValueAmount_;

        if (paymentToken_.isNativeToken()) {
            subscriptionValueAmount_ = subscriptionCost_;
        } else {
            IERC20(paymentToken_).approve(address(subscriptionManager_), subscriptionCost_);
        }

        subscriptionManager_.buySubscription{value: subscriptionValueAmount_}(
            vaultAddr_,
            paymentToken_,
            initialSubscriptionDuration_
        );
    }

    /// @inheritdoc IVaultFactory
    function deployVaultWithSBT(
        address masterKey_,
        address sbt_,
        uint256 tokenId_,
        string memory vaultName_
    ) external nonReentrant returns (address vaultAddr_) {
        vaultAddr_ = _deployVault(masterKey_, vaultName_);

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            _getVaultFactoryStorage().vaultSubscriptionManager
        );

        subscriptionManager_.buySubscriptionWithSBT(vaultAddr_, sbt_, msg.sender, tokenId_);
    }

    /// @inheritdoc IVaultFactory
    function deployVaultWithSignature(
        address masterKey_,
        uint64 initialSubscriptionDuration_,
        bytes memory signature_,
        string memory vaultName_
    ) external nonReentrant returns (address vaultAddr_) {
        vaultAddr_ = _deployVault(masterKey_, vaultName_);

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            _getVaultFactoryStorage().vaultSubscriptionManager
        );

        subscriptionManager_.buySubscriptionWithSignature(
            msg.sender,
            vaultAddr_,
            initialSubscriptionDuration_,
            signature_
        );
    }

    /// @inheritdoc IVaultFactory
    function getVaultCountByCreator(address vaultCreator_) external view returns (uint256) {
        return _getVaultFactoryStorage().vaultsByCreator[vaultCreator_].length();
    }

    /// @inheritdoc IVaultFactory
    function getVaultsByCreatorPart(
        address vaultCreator_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory) {
        return _getVaultFactoryStorage().vaultsByCreator[vaultCreator_].part(offset_, limit_);
    }

    /// @inheritdoc IVaultFactory
    function isVault(address vaultAddr_) external view returns (bool) {
        return bytes(getVaultName(vaultAddr_)).length > 0;
    }

    /// @inheritdoc IVaultFactory
    function getTokenLimitAmount(address token_) external view returns (uint256) {
        return _getVaultFactoryStorage().tokensLimitAmounts[token_];
    }

    /// @inheritdoc IVaultFactory
    function getVaultSubscriptionManager() external view returns (address) {
        return _getVaultFactoryStorage().vaultSubscriptionManager;
    }

    /// @inheritdoc IVaultFactory
    function getVaultImplementation() external view returns (address) {
        return _getVaultFactoryStorage().vaultImplementation;
    }

    /// @inheritdoc IVaultFactory
    function predictVaultAddress(
        address masterKey_,
        uint256 nonce_
    ) external view returns (address) {
        return CREATE3.predictDeterministicAddress(getDeployVaultSalt(masterKey_, nonce_));
    }

    /// @inheritdoc IVaultFactory
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @inheritdoc IVaultFactory
    function isVaultNameAvailable(string memory name_) public view returns (bool) {
        return getVaultByName(name_) == address(0);
    }

    /// @inheritdoc IVaultFactory
    function getVaultName(address vault_) public view returns (string memory) {
        return _getVaultFactoryStorage().vaultNames[vault_];
    }

    /// @inheritdoc IVaultFactory
    function getVaultByName(string memory vaultName_) public view returns (address) {
        return _getVaultFactoryStorage().namesToVaults[keccak256(bytes(vaultName_))];
    }

    /// @inheritdoc IVaultFactory
    function getDeployVaultSalt(address masterKey_, uint256 nonce_) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(masterKey_, nonce_));
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

    function _deployVault(
        address masterKey_,
        string memory vaultName_
    ) internal returns (address vaultAddr_) {
        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        bytes32 salt_ = getDeployVaultSalt(masterKey_, _useNonce(masterKey_));

        vaultAddr_ = _deploy3($.vaultImplementation, salt_);

        IVault(vaultAddr_).initialize(masterKey_);

        _setVaultName(vaultAddr_, vaultName_);

        $.vaultsByCreator[msg.sender].add(vaultAddr_);

        emit VaultDeployed(msg.sender, vaultAddr_, masterKey_, vaultName_);
    }

    function _setVaultName(address vault_, string memory vaultName_) internal {
        require(bytes(vaultName_).length >= MIN_VAULT_NAME_LENGTH, VaultNameTooShort(vaultName_));
        require(isVaultNameAvailable(vaultName_), VaultNameAlreadyTaken(vaultName_));

        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        $.vaultNames[vault_] = vaultName_;
        $.namesToVaults[keccak256(bytes(vaultName_))] = vault_;
    }

    function _deploy3(address implementation_, bytes32 salt_) internal returns (address) {
        return CREATE3.deployDeterministic(_getVaultProxyCreationCode(implementation_), salt_);
    }

    /**
     * @notice Authorize upgrade (UUPS pattern)
     * @param newImplementation_ The new implementation address
     * @dev Only callable by factory owner
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _getVaultProxyCreationCode(
        address implementation_
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation_, new bytes(0))
            );
    }
}
