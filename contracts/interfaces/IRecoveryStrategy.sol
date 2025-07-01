// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IRecoveryStrategy {
    function validateAccountRecoveryData(bytes memory recoveryData_) external view;

    function recover(bytes memory recoveryData_) external;
}
