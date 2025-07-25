// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

library EIP712SignatureChecker {
    error InvalidSignature();

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
