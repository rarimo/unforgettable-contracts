// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IRecoveryStrategy {
    function recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryData_
    ) external;

    function getRecoveryManager() external view returns (address);

    function validateRecoveryData(bytes memory recoveryData_) external view;
}
