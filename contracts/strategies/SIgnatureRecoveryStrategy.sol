// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {ISignatureRecoveryStrategy} from "../interfaces/strategies/ISignatureRecoveryStrategy.sol";

import {ARecoveryStrategy} from "./ARecoveryStrategy.sol";

contract SignatureRecoveryStrategy is
    ISignatureRecoveryStrategy,
    ARecoveryStrategy,
    EIP712Upgradeable
{
    bytes32 public constant EMERGENCY_WITHDRAW_TYPEHASH =
        keccak256("SignatureRecovery(address account,address newOwner,uint256 nonce)");

    function initialize(address recoveryManagerAddr_) external initializer {
        __EIP712_init("ATimeLockRecovery", "v1.0.0");
        __ARecoveryStrategy_init(recoveryManagerAddr_);
    }

    function hashSignatureRecovery(
        address account_,
        address newOwner_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(EMERGENCY_WITHDRAW_TYPEHASH, account_, newOwner_, nonce_))
            );
    }

    function _recoverAccount(
        address account_,
        address newOwner_,
        bytes memory recoveryDataRaw_
    ) internal override {
        SignatureRecoveryData memory recoveryData_ = abi.decode(
            recoveryDataRaw_,
            (SignatureRecoveryData)
        );
        address recoveryKey_ = abi.decode(recoveryData_.accountRecoveryData, (address));

        // Verify EIP712 signature
        bytes32 hash_ = hashSignatureRecovery(account_, newOwner_, _useNonce(account_));
        require(
            SignatureChecker.isValidSignatureNow(recoveryKey_, hash_, recoveryData_.signature),
            RecoveryFailed()
        );
    }

    function _validateAccountRecoveryData(bytes memory recoveryData_) internal pure override {
        address recoveryKey_ = abi.decode(recoveryData_, (address));

        require(recoveryKey_ != address(0), InvalidAccountRecoveryData());
    }
}
