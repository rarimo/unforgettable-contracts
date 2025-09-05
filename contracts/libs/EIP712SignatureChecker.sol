// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title EIP712SignatureChecker
 * @notice A wrapper around the OpenZeppelin `SignatureChecker` contract for EIP-712 signature validations.
 */
library EIP712SignatureChecker {
    /**
     * @notice Thrown when the provided signature is invalid.
     */
    error InvalidSignature();

    /**
     * @notice A function to validate an EIP-712 signature for provided signer and hash.
     * @dev Reverts if the signature is invalid.
     * @param signer_ The account expected to have signed the hash.
     * @param hash_ The hash that was signed.
     * @param signature_ The signature to validate.
     */
    function checkSignature(
        address signer_,
        bytes32 hash_,
        bytes memory signature_
    ) internal view {
        require(
            SignatureChecker.isValidSignatureNow(signer_, hash_, signature_),
            InvalidSignature()
        );
    }
}
