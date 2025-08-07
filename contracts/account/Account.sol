// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC7821} from "solady/src/accounts/ERC7821.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {BaseAccountRecovery} from "./BaseAccountRecovery.sol";

contract Account is ERC7821, BaseAccountRecovery {
    function isValidSignature(
        bytes32 hash_,
        bytes calldata signature_
    ) public view virtual returns (bytes4 result_) {
        address recovered_ = ECDSA.recover(hash_, signature_);
        bool success_ = recovered_ == address(this) || recovered_ == trustedExecutor;
        /// @solidity memory-safe-assembly
        assembly {
            result_ := shl(224, or(0x1626ba7e, sub(0, iszero(success_))))
        }
    }

    function _execute(
        bytes32 /* mode_ */,
        bytes calldata /* executionData_ */,
        Call[] calldata calls_,
        bytes calldata /* opData_ */
    ) internal override onlySelfOrTrustedExecutor {
        _execute(calls_, bytes32(0));
    }
}
