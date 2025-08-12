// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

contract Base7702AccountRecovery is AAccountRecovery {
    bytes32 public constant BASE_7702_ACCOUNT_RECOVERY_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.7702.account.recovery.storage");

    struct Base7702AccountRecoveryStorage {
        address trustedExecutor;
    }

    error NotSelfOrTrustedExecutor(address account);

    function _getBaseAccountRecoveryStorage()
        private
        pure
        returns (Base7702AccountRecoveryStorage storage _ars)
    {
        bytes32 slot_ = BASE_7702_ACCOUNT_RECOVERY_STORAGE_SLOT;

        assembly {
            _ars.slot := slot_
        }
    }

    modifier onlySelfOrTrustedExecutor() {
        require(
            msg.sender == address(this) || msg.sender == getTrustedExecutor(),
            NotSelfOrTrustedExecutor(msg.sender)
        );
        _;
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function addRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external payable override onlySelfOrTrustedExecutor {
        _addRecoveryProvider(provider_, recoveryData_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function removeRecoveryProvider(
        address provider_
    ) external payable override onlySelfOrTrustedExecutor {
        _removeRecoveryProvider(provider_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function recoverAccess(
        bytes memory subject_,
        address provider_,
        bytes memory proof_
    ) external override returns (bool) {
        _validateRecovery(subject_, provider_, proof_);

        address newTrustedExecutor_ = abi.decode(subject_, (address));

        _getBaseAccountRecoveryStorage().trustedExecutor = newTrustedExecutor_;

        emit AccessRecovered(subject_);

        return true;
    }

    function getTrustedExecutor() public view returns (address) {
        return _getBaseAccountRecoveryStorage().trustedExecutor;
    }
}
