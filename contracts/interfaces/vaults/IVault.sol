// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVault {
    error NoActiveSubscription();
    error ZeroAmount();
    error TokenLimitExceeded(address token);
    error ZeroMasterKey();
    error InvalidNewEnabledStatus();
    error VaultIsNotEnabled();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EnabledStatusUpdated(bool enabled);
    event TokensDeposited(address indexed token, address sender, uint256 amount);
    event TokensWithdrawn(address indexed token, address recipient, uint256 amount);

    function initialize(address masterKey_) external;

    function updateMasterKey(address newMasterKey_, bytes memory signature_) external;

    function updateEnabledStatus(bool enabled_, bytes memory signature_) external;

    function withdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 tokensAmount_,
        bytes memory signature_
    ) external;

    function deposit(address tokenAddr_, uint256 amountToDeposit_) external payable;

    function owner() external view returns (address);

    function getBalance(address tokenAddr_) external view returns (uint256);

    function isVaultEnabled() external view returns (bool);

    function hashWithdrawTokens(
        address tokenAddr_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_
    ) external view returns (bytes32);

    function hashUpdateEnabledStatus(
        bool enabled_,
        uint256 nonce_
    ) external view returns (bytes32);

    function hashUpdateMasterKey(
        address newMasterKey_,
        uint256 nonce_
    ) external view returns (bytes32);
}
