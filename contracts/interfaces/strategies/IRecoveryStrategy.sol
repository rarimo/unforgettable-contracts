// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IRecoveryStrategy {
    function recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryData_
    ) external;

    function validateAccountRecoveryData(bytes memory recoveryData_) external view;

    function getRecoveryManager() external view returns (address);
}
