// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAccountRecovery {
    event OwnershipRecovered(address indexed oldOwner, address indexed newOwner);
    event RecoveryProviderAdded(address indexed provider);
    event RecoveryProviderRemoved(address indexed provider);

    function addRecoveryProvider(address provider, bytes memory recoveryData) external;

    function removeRecoveryProvider(address provider) external;

    function recoveryProviderAdded(address provider) external view returns (bool);

    function recoverOwnership(
        address newOwner,
        address provider,
        bytes memory proof
    ) external returns (bool);
}
