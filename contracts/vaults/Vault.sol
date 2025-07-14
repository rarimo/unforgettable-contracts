// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IRecoveryProvider} from "../interfaces/IRecoveryProvider.sol";
import {IVault} from "../interfaces/vaults/IVault.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";
import {IVaultSubscriptionManager} from "../interfaces/vaults/IVaultSubscriptionManager.sol";

contract Vault is IVault, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 public constant VAULT_STORAGE_SLOT = keccak256("unforgettable.contract.vault.storage");

    struct VaultStorage {
        IVaultFactory vaultFactory;
        uint128 recoveryLockedUntil;
        uint64 recoveryTimelock;
        uint64 recoveryDelay;
        address pendingOwnerAddr;
        uint64 confirmationLockedUntil;
        EnumerableSet.AddressSet recoveryProviders;
    }

    function _getVaultStorage() private pure returns (VaultStorage storage _vs) {
        bytes32 slot_ = VAULT_STORAGE_SLOT;

        assembly {
            _vs.slot := slot_
        }
    }

    function initialize(VaultInitParams memory initParams_) external initializer {
        __Ownable_init(initParams_.vaultOwner);

        VaultStorage storage $ = _getVaultStorage();

        IVaultFactory factory_ = IVaultFactory(msg.sender);
        $.vaultFactory = factory_;

        _setRecoveryTimelock(initParams_.recoveryTimelock);
        _setRecoveryDelay(initParams_.recoveryDelay);

        $.recoveryLockedUntil = uint128(block.timestamp + initParams_.recoveryTimelock);

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            factory_.getVaultSubscriptionManager()
        );
        address recoveryManager_ = factory_.getRecoveryManager();

        uint256 subscriptionCost_ = subscriptionManager_.getSubscriptionCost(
            address(this),
            initParams_.paymentToken,
            initParams_.initialSubscriptionDuration
        );
        IERC20(initParams_.paymentToken).approve(recoveryManager_, subscriptionCost_);

        bytes memory fullRecoveryData_ = abi.encode(
            address(subscriptionManager_),
            initParams_.paymentToken,
            initParams_.initialSubscriptionDuration,
            initParams_.recoveryData
        );

        _addRecoveryProvider(recoveryManager_, fullRecoveryData_);
    }

    receive() external payable {
        depositNative();
    }

    function setRecoveryTimelock(uint64 recoveryTimelock_) external onlyOwner {
        _setRecoveryTimelock(recoveryTimelock_);
    }

    function setRecoveryDelay(uint64 recoveryDelay_) external onlyOwner {
        _setRecoveryDelay(recoveryDelay_);
    }

    function addRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external onlyOwner {
        _addRecoveryProvider(provider_, recoveryData_);
    }

    function removeRecoveryProvider(address provider_) external onlyOwner {
        _hasRecoveryProvider(provider_);

        IRecoveryProvider(provider_).unsubscribe();

        _getVaultStorage().recoveryProviders.remove(provider_);

        emit RecoveryProviderRemoved(provider_);
    }

    function cancelRecovery() external onlyOwner {
        VaultStorage storage $ = _getVaultStorage();

        address pendingOwnerAddr_ = $.pendingOwnerAddr;

        delete $.pendingOwnerAddr;
        delete $.confirmationLockedUntil;

        emit RecoveryCancelled(pendingOwnerAddr_);
    }

    function withdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 tokensAmount_
    ) external onlyOwner {
        VaultStorage storage $ = _getVaultStorage();

        IVaultSubscriptionManager subscriptionManager_ = IVaultSubscriptionManager(
            $.vaultFactory.getVaultSubscriptionManager()
        );
        require(subscriptionManager_.hasActiveSubscription(address(this)), NoActiveSubscription());

        if (isNativeToken(tokenAddr_)) {
            Address.sendValue(payable(recipient_), tokensAmount_);
        } else {
            IERC20(tokenAddr_).safeTransfer(recipient_, tokensAmount_);
        }

        emit TokensWithdrawn(tokenAddr_, recipient_, tokensAmount_);
    }

    function recoverOwnership(
        address newOwner_,
        address provider_,
        bytes memory proof_
    ) external returns (bool) {
        VaultStorage storage $ = _getVaultStorage();

        require(block.timestamp > $.recoveryLockedUntil, RecoveryLocked());

        _hasRecoveryProvider(provider_);

        IRecoveryProvider(provider_).recover(newOwner_, proof_);

        $.pendingOwnerAddr = newOwner_;
        $.confirmationLockedUntil = uint64(block.timestamp + $.recoveryDelay);

        return true;
    }

    function confirmRecovery() external {
        VaultStorage storage $ = _getVaultStorage();

        require(msg.sender == $.pendingOwnerAddr, NotAPendingOwner(msg.sender));
        require(block.timestamp > $.confirmationLockedUntil, RecoveryConfirmationLocked());

        address currentOwner_ = owner();
        transferOwnership(msg.sender);

        $.recoveryLockedUntil = uint128(block.timestamp + $.recoveryTimelock);

        delete $.pendingOwnerAddr;
        delete $.confirmationLockedUntil;

        emit OwnershipRecovered(currentOwner_, msg.sender);
    }

    function depositERC20(address tokenAddr_, uint256 amountToDeposit_) external {
        uint256 limitAmount_ = _getVaultStorage().vaultFactory.getTokenLimitAmount(tokenAddr_);

        require(
            getSelfBalance(tokenAddr_) + amountToDeposit_ <= limitAmount_,
            TokenLimitExceeded(tokenAddr_)
        );

        IERC20(tokenAddr_).safeTransferFrom(msg.sender, address(this), amountToDeposit_);

        emit TokensDeposited(tokenAddr_, msg.sender, amountToDeposit_);
    }

    function depositNative() public payable {
        require(msg.value > 0, ZeroAmount());

        uint256 limitAmount_ = _getVaultStorage().vaultFactory.getTokenLimitAmount(ETH_ADDR);

        require(getSelfBalance(ETH_ADDR) <= limitAmount_, TokenLimitExceeded(ETH_ADDR));

        emit TokensDeposited(ETH_ADDR, msg.sender, msg.value);
    }

    function recoveryProviderAdded(address provider_) public view returns (bool) {
        return _getVaultStorage().recoveryProviders.contains(provider_);
    }

    function getSelfBalance(address tokenAddr_) public view returns (uint256) {
        if (isNativeToken(tokenAddr_)) {
            return address(this).balance;
        } else {
            return IERC20(tokenAddr_).balanceOf(address(this));
        }
    }

    function isNativeToken(address tokenAddr_) public pure returns (bool) {
        return ETH_ADDR == tokenAddr_;
    }

    function _setRecoveryTimelock(uint64 recoveryTimelock_) internal {
        _getVaultStorage().recoveryTimelock = recoveryTimelock_;

        emit RecoveryTimelockUpdated(recoveryTimelock_);
    }

    function _setRecoveryDelay(uint64 recoveryDelay_) internal {
        _getVaultStorage().recoveryDelay = recoveryDelay_;

        emit RecoveryDelayUpdated(recoveryDelay_);
    }

    function _addRecoveryProvider(address provider_, bytes memory recoveryData_) internal {
        IRecoveryProvider(provider_).subscribe(recoveryData_);

        _getVaultStorage().recoveryProviders.add(provider_);

        emit RecoveryProviderAdded(provider_);
    }

    function _hasRecoveryProvider(address provider_) internal view {
        require(recoveryProviderAdded(provider_), RecoveryProviderDoesNotExist(provider_));
    }
}
