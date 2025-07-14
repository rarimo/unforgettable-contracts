// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccountRecovery} from "../IAccountRecovery.sol";

interface IVault is IAccountRecovery {
    struct VaultInitParams {
        address vaultOwner;
        address paymentToken;
        uint256 initialSubscriptionDuration;
        uint64 recoveryTimelock;
        uint64 recoveryDelay;
        bytes recoveryData;
    }

    error RecoveryProviderDoesNotExist(address provider);
    error RecoveryLocked();
    error NoActiveSubscription();
    error NotAPendingOwner(address account);
    error RecoveryConfirmationLocked();
    error ZeroAmount();
    error TokenLimitExceeded(address token);

    event RecoveryTimelockUpdated(uint64 newRecoveryTimelock);
    event RecoveryDelayUpdated(uint64 newRecoveryDelay);
    event RecoveryCancelled(address pendingOwnerAddr);
    event TokensDeposited(address indexed token, address sender, uint256 amount);
    event TokensWithdrawn(address indexed token, address recipient, uint256 amount);

    function initialize(VaultInitParams memory initParams_) external;
}
