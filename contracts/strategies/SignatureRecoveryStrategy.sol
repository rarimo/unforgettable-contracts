// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {EIP712SignatureChecker} from "../libs/EIP712SignatureChecker.sol";
import {ISignatureRecoveryStrategy} from "../interfaces/strategies/ISignatureRecoveryStrategy.sol";

import {ARecoveryStrategy} from "./ARecoveryStrategy.sol";

contract SignatureRecoveryStrategy is
    ISignatureRecoveryStrategy,
    ARecoveryStrategy,
    EIP712Upgradeable
{
    using EIP712SignatureChecker for address;

    bytes32 public constant SIGNATURE_RECOVERY_TYPEHASH =
        keccak256("SignatureRecovery(address account,bytes32 objectHash,uint256 nonce)");

    function initialize(address recoveryManagerAddr_) external initializer {
        __EIP712_init("SignatureRecoveryStrategy", "v1.0.0");
        __ARecoveryStrategy_init(recoveryManagerAddr_);
    }

    function hashSignatureRecovery(
        address account_,
        bytes memory object_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(SIGNATURE_RECOVERY_TYPEHASH, account_, keccak256(object_), nonce_)
                )
            );
    }

    function _recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryDataRaw_
    ) internal override {
        (bytes memory accountRecoveryData_, bytes memory signature_) = abi.decode(
            recoveryDataRaw_,
            (bytes, bytes)
        );
        address recoveryKey_ = abi.decode(accountRecoveryData_, (address));

        // Verify EIP712 signature
        bytes32 hash_ = hashSignatureRecovery(account_, object_, _useNonce(account_));

        recoveryKey_.checkSignature(hash_, signature_);
    }

    function _validateAccountRecoveryData(bytes memory recoveryData_) internal pure override {
        address recoveryKey_ = abi.decode(recoveryData_, (address));

        require(recoveryKey_ != address(0), InvalidAccountRecoveryData());
    }
}
