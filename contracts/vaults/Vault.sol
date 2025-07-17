// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";

import {TokensHelper} from "../libs/TokensHelper.sol";
import {EIP712SignatureChecker} from "../libs/EIP712SignatureChecker.sol";

contract Vault is IVault, NoncesUpgradeable, EIP712Upgradeable {
    using TokensHelper for address;
    using EIP712SignatureChecker for address;

    bytes32 public constant WITHDRAW_TOKENS_TYPEHASH =
        keccak256("WithdrawTokens(address token,address to,uint256 amount,uint256 nonce)");
    bytes32 public constant UPDATE_DISABLED_STATUS_TYPEHASH =
        keccak256("UpdateDisabledStatus(bool newDisabledValue,uint256 nonce)");
    bytes32 public constant UPDATE_MASTER_KEY_TYPEHASH =
        keccak256("UpdateMasterKey(address newMasterKey,uint256 nonce)");

    bytes32 public constant VAULT_STORAGE_SLOT = keccak256("unforgettable.contract.vault.storage");

    struct VaultStorage {
        address masterKey;
        IVaultFactory vaultFactory;
        bool disabled;
    }

    constructor() {
        _disableInitializers();
    }

    function _getVaultStorage() private pure returns (VaultStorage storage _vs) {
        bytes32 slot_ = VAULT_STORAGE_SLOT;

        assembly {
            _vs.slot := slot_
        }
    }

    function initialize(address masterKey_) external initializer {
        __EIP712_init("Vault", "v1.0.0");

        VaultStorage storage $ = _getVaultStorage();

        _updateMasterKey(masterKey_);

        $.vaultFactory = IVaultFactory(msg.sender);
    }

    receive() external payable {
        deposit(TokensHelper.ETH_ADDR, msg.value);
    }

    function updateMasterKey(address newMasterKey_, bytes memory signature_) external {
        bytes32 updateMasterKeyHash_ = hashUpdateMasterKey(newMasterKey_, _useNonce(owner()));
        owner().checkSignature(updateMasterKeyHash_, signature_);

        _updateMasterKey(newMasterKey_);
    }

    function updateDisabledStatus(bool newDisabledStatus_, bytes memory signature_) external {
        VaultStorage storage $ = _getVaultStorage();

        bytes32 updateDisabledStatusHash_ = hashUpdateDisabledStatus(
            newDisabledStatus_,
            _useNonce(owner())
        );
        owner().checkSignature(updateDisabledStatusHash_, signature_);

        require(newDisabledStatus_ != $.disabled, InvalidNewDisabledStatus());

        $.disabled = newDisabledStatus_;

        emit DisabledStatusUpdated(newDisabledStatus_);
    }

    function withdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 tokensAmount_,
        bytes memory signature_
    ) external {
        VaultStorage storage $ = _getVaultStorage();

        _checkTokensAmount(tokensAmount_);

        bytes32 withdrawHash_ = hashWithdrawTokens(
            tokenAddr_,
            recipient_,
            tokensAmount_,
            _useNonce(owner())
        );
        owner().checkSignature(withdrawHash_, signature_);

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            $.vaultFactory.getVaultSubscriptionManager()
        );
        require(subscriptionManager_.hasActiveSubscription(address(this)), NoActiveSubscription());

        tokenAddr_.sendTokens(recipient_, tokensAmount_);

        emit TokensWithdrawn(tokenAddr_, recipient_, tokensAmount_);
    }

    function deposit(address tokenAddr_, uint256 amountToDeposit_) public payable {
        require(isVaultDisabled(), VaultDisabled());
        _checkTokensAmount(amountToDeposit_);

        uint256 limitAmount_ = _getVaultStorage().vaultFactory.getTokenLimitAmount(tokenAddr_);

        uint256 newBalance_ = tokenAddr_.getSelfBalance();

        if (!tokenAddr_.isNativeToken()) {
            newBalance_ += amountToDeposit_;
        }

        require(newBalance_ <= limitAmount_, TokenLimitExceeded(tokenAddr_));

        tokenAddr_.receiveTokens(msg.sender, amountToDeposit_);

        emit TokensDeposited(tokenAddr_, msg.sender, amountToDeposit_);
    }

    function getBalance(address tokenAddr_) external view returns (uint256) {
        return tokenAddr_.getSelfBalance();
    }

    function owner() public view returns (address) {
        return _getVaultStorage().masterKey;
    }

    function isVaultDisabled() public view returns (bool) {
        return _getVaultStorage().disabled;
    }

    function hashWithdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(WITHDRAW_TOKENS_TYPEHASH, tokenAddr_, recipient_, amount_, nonce_)
                )
            );
    }

    function hashUpdateDisabledStatus(
        bool newDisabledValue_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(UPDATE_DISABLED_STATUS_TYPEHASH, newDisabledValue_, nonce_))
            );
    }

    function hashUpdateMasterKey(
        address newMasterKey_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(UPDATE_MASTER_KEY_TYPEHASH, newMasterKey_, nonce_))
            );
    }

    function _updateMasterKey(address newMasterKey_) internal {
        VaultStorage storage $ = _getVaultStorage();

        require(newMasterKey_ != address(0), ZeroMasterKey());

        address currentMasterKey_ = $.masterKey;
        $.masterKey = newMasterKey_;

        emit OwnershipTransferred(currentMasterKey_, newMasterKey_);
    }

    function _checkTokensAmount(uint256 amount_) internal pure {
        require(amount_ > 0, ZeroAmount());
    }
}
