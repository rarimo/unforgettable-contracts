// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVaultFactory {
    function isVault(address vaultAddr) external view returns (bool);

    function getTokenLimitAmount(address token_) external view returns (uint256);

    function getVaultSubscriptionManager() external view returns (address);

    function getRecoveryManager() external view returns (address);
}
