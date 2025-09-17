// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRecoveryStrategy} from "./IRecoveryStrategy.sol";

/**
 * @title ISignatureRecoveryStrategy
 * @notice Interface for the SignatureRecoveryStrategy contract
 */
interface ISignatureRecoveryStrategy is IRecoveryStrategy {
    /**
     * @notice Thrown when the provided account recovery data is invalid.
     */
    error InvalidAccountRecoveryData();

    /**
     * @notice A function to compute the EIP-712 hash for a signature-based account recovery.
     * @param account_ The account to be recovered.
     * @param object_ Encoded object representing the recovery target.
     * @param nonce_ Nonce used in a signature to prevent replay attacks.
     * @return The EIP-712 hash of the recovery operation to be signed by the recovery key.
     */
    function hashSignatureRecovery(
        address account_,
        bytes memory object_,
        uint256 nonce_
    ) external view returns (bytes32);
}
