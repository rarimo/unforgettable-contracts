// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Paginator} from "@solarity/solidity-lib/libs/arrays/Paginator.sol";

import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/subscription/IVaultSubscriptionManager.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";

/**
 * @title VaultFactory
 * @notice Factory contract for deploying Vault instances using CREATE2
 */
contract VaultFactory is
    IVaultFactory,
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

    struct VaultFactoryStorage {
        address vaultImplementation;
        address vaultSubscriptionManager;
        mapping(address => uint256) tokensLimitAmounts;
        mapping(address => bool) deployedVaults;
        mapping(address => EnumerableSet.AddressSet) vaultsByCreator;
    }

    constructor() {
        _disableInitializers();
    }

    function _getVaultFactoryStorage() private pure returns (VaultFactoryStorage storage _vfs) {
        bytes32 slot_ = VAULT_FACTORY_STORAGE_SLOT;

        assembly {
            _vfs.slot := slot_
        }
    }

    function initialize(address vaultImplementation_) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _updateVaultImplementation(vaultImplementation_);
    }

    function secondStepInitialize(
        address vaultSubscriptionManager_
    ) external onlyOwner reinitializer(2) {
        _getVaultFactoryStorage().vaultSubscriptionManager = vaultSubscriptionManager_;
    }

    function updateVaultImplementation(address newVaultImpl_) external onlyOwner {
        _updateVaultImplementation(newVaultImpl_);
    }

    function updateTokenLimitAmount(address token_, uint256 newLimitAmount_) external onlyOwner {
        _updateTokenLimitAmount(token_, newLimitAmount_);
    }

    function deployVault(
        address masterKey_,
        address paymentToken_,
        uint64 initialSubscriptionDuration_,
        string memory vaultName_
    ) external payable nonReentrant returns (address vaultAddr_) {
        VaultFactoryStorage storage $ = _getVaultFactoryStorage();

        bytes32 salt_ = getDeployVaultSalt(msg.sender, _useNonce(msg.sender));

        vaultAddr_ = _deploy2($.vaultImplementation, salt_);

        IVault(vaultAddr_).initialize(masterKey_);

        $.deployedVaults[vaultAddr_] = true;
        $.vaultsByCreator[msg.sender].add(vaultAddr_);

        _buyInitialSubscription(
            paymentToken_,
            vaultAddr_,
            initialSubscriptionDuration_,
            vaultName_
        );

        emit VaultDeployed(msg.sender, vaultAddr_, masterKey_);
    }

    function getVaultCountByCreator(address vaultCreator_) external view returns (uint256) {
        return _getVaultFactoryStorage().vaultsByCreator[vaultCreator_].length();
    }

    function getVaultsByCreatorPart(
        address vaultCreator_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory) {
        return _getVaultFactoryStorage().vaultsByCreator[vaultCreator_].part(offset_, limit_);
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

    function getVaultImplementation() external view returns (address) {
        return _getVaultFactoryStorage().vaultImplementation;
    }

    function predictVaultAddress(
        address implementation_,
        address creator_,
        uint256 nonce_
    ) external view returns (address) {
        return _predictAddress(implementation_, getDeployVaultSalt(creator_, nonce_));
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function getDeployVaultSalt(address creator_, uint256 nonce_) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(creator_, nonce_));
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

    function _deploy2(address implementation_, bytes32 salt_) internal returns (address) {
        return payable(address(new ERC1967Proxy{salt: salt_}(implementation_, new bytes(0))));
    }

    function _buyInitialSubscription(
        address paymentToken_,
        address vaultAddr_,
        uint64 duration_,
        string memory vaultName_
    ) internal {
        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            _getVaultFactoryStorage().vaultSubscriptionManager
        );

        uint256 subscriptionCost_ = subscriptionManager_.getSubscriptionCost(
            vaultAddr_,
            address(paymentToken_),
            duration_
        );

        uint256 vaultNameCost_ = subscriptionManager_.getVaultNameCost(
            address(paymentToken_),
            vaultName_
        );

        uint256 totalCost_ = subscriptionCost_ + vaultNameCost_;

        paymentToken_.receiveTokens(msg.sender, totalCost_);

        uint256 subscriptionValueAmount_;
        uint256 nameValueAmount_;

        if (paymentToken_.isNativeToken()) {
            subscriptionValueAmount_ = subscriptionCost_;
            nameValueAmount_ = vaultNameCost_;
        } else {
            IERC20(paymentToken_).approve(address(subscriptionManager_), totalCost_);
        }

        subscriptionManager_.buySubscription{value: subscriptionValueAmount_}(
            vaultAddr_,
            address(paymentToken_),
            duration_
        );

        subscriptionManager_.updateVaultName{value: nameValueAmount_}(
            vaultAddr_,
            address(paymentToken_),
            vaultName_
        );
    }

    /**
     * @notice Authorize upgrade (UUPS pattern)
     * @param newImplementation_ The new implementation address
     * @dev Only callable by factory owner
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _predictAddress(
        address implementation_,
        bytes32 salt_
    ) internal view returns (address) {
        bytes32 bytecodeHash_ = keccak256(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation_, new bytes(0))
            )
        );

        return Create2.computeAddress(salt_, bytecodeHash_);
    }
}
