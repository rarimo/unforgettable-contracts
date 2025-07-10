// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRecoveryStrategy} from "./IRecoveryStrategy.sol";

interface ISignatureRecoveryStrategy is IRecoveryStrategy {
    struct SignatureRecoveryData {
        bytes accountRecoveryData;
        bytes signature;
    }

    error InvalidAccountRecoveryData();
    error RecoveryFailed();

    function hashSignatureRecovery(
        address account_,
        address newOwner_,
        uint256 nonce_
    ) external view returns (bytes32);
}
