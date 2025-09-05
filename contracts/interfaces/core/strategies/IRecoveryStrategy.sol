// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRecoveryStrategy
 * @notice Interface for the ARecoveryStrategy contract
 */
interface IRecoveryStrategy {
    /**
     * @notice Thrown when a caller is not the stored recovery manager.
     * @param account The caller address.
     */
    error NotARecoveryManager(address account);

    /**
     * @notice A function to verify the account recovery request.
     * @dev Can only be called by the recovery manager.
     * @param account_ Address of the account to recover.
     * @param object_ Encoded object representing the recovery target.
     * @param recoveryData_ Encoded data required to perform the recovery.
     */
    function recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryData_
    ) external;

    /**
     * @notice A function to retrieve the address of the stored recovery manager.
     * @return The recovery manager address.
     */
    function getRecoveryManager() external view returns (address);

    /**
     * @notice A function to validate recovery data without performing the recovery.
     * @param recoveryData_ Encoded recovery data to validate.
     * @dev Can be used to check if recovery data is provided in a valid format.
     */
    function validateRecoveryData(bytes memory recoveryData_) external view;
}
