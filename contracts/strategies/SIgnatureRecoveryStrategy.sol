// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {IRecoveryStrategy} from "../interfaces/IRecoveryStrategy.sol";

contract SignatureRecoveryStrategy is IRecoveryStrategy, EIP712Upgradeable {
    bytes32 public constant EMERGENCY_WITHDRAW_TYPEHASH =
        keccak256("SignatureRecovery(address account,address newOwner)");
    bytes32 public constant SIGNATURE_RECOVERY_STRATEGY_STORAGE_SLOT =
        keccak256("unforgettable.contract.signature.recovery.strategy.storage");

    struct SignatureRecoveryStrategyStorage {
        address recoveryManagerAddr;
    }

    struct SignatureRecoveryData {
        address account;
        address newOwner;
        bytes accountRecoveryData;
        bytes signature;
    }

    error NotARecoveryManager(address account);
    error InvalidAccountRecoveryData();
    error RecoveryFailed();

    modifier onlyRecoveryManager() {
        _onlyRecoveryManager();
        _;
    }

    function _getSignatureRecoveryStrategyStorage()
        private
        pure
        returns (SignatureRecoveryStrategyStorage storage _srss)
    {
        bytes32 slot_ = SIGNATURE_RECOVERY_STRATEGY_STORAGE_SLOT;

        assembly {
            _srss.slot := slot_
        }
    }

    function initialize(address recoveryManagerAddr_) external initializer {
        __EIP712_init("ATimeLockRecovery", "v1.0.0");

        _getSignatureRecoveryStrategyStorage().recoveryManagerAddr = recoveryManagerAddr_;
    }

    function validateAccountRecoveryData(bytes memory recoveryData_) external pure {
        address recoveryKey_ = abi.decode(recoveryData_, (address));

        require(recoveryKey_ != address(0), InvalidAccountRecoveryData());
    }

    function recover(bytes memory recoveryDataRaw_) external onlyRecoveryManager {
        SignatureRecoveryData memory recoveryData_ = abi.decode(
            recoveryDataRaw_,
            (SignatureRecoveryData)
        );
        address recoveryKey_ = abi.decode(recoveryData_.accountRecoveryData, (address));

        // Verify EIP712 signature
        bytes32 hash_ = hashSignatureRecovery(recoveryData_.account, recoveryData_.newOwner);
        require(
            SignatureChecker.isValidSignatureNow(recoveryKey_, hash_, recoveryData_.signature),
            RecoveryFailed()
        );
    }

    function hashSignatureRecovery(
        address account_,
        address newOwner_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(EMERGENCY_WITHDRAW_TYPEHASH, account_, newOwner_))
            );
    }

    function _onlyRecoveryManager() internal view {
        require(
            msg.sender == _getSignatureRecoveryStrategyStorage().recoveryManagerAddr,
            NotARecoveryManager(msg.sender)
        );
    }
}
