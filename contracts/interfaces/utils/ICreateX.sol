// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ICreateX
 * @notice Interface for deterministic contract deployment using CREATE3 regardless
 *         of contract initialization code or deployer nonce.
 */
interface ICreateX {
    /**
     * @notice A function to deploy a contract using CREATE3 at a deterministic address.
     * @param salt_ A salt used to determine the deployment address.
     * @param initCode_ The initialization bytecode of the contract to deploy.
     * @return newContract_ The address of the newly deployed contract.
     */
    function deployCreate3(
        bytes32 salt_,
        bytes memory initCode_
    ) external payable returns (address newContract_);

    /**
     * @notice A function to compute the deterministic address for a contract deployed via CREATE3.
     * @param salt_ The salt to use for address computation.
     * @return computedAddress_ The address where the contract will be deployed.
     */
    function computeCreate3Address(bytes32 salt_) external view returns (address computedAddress_);
}
