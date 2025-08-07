// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

contract BaseAccountRecovery is AAccountRecovery {
    bytes32 public constant BASE_ACCOUNT_RECOVERY_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.account.recovery.storage");

    struct BaseAccountRecoveryStorage {
        address trustedExecutor;
    }

    error NotSelfOrTrustedExecutor(address account);

    function _getBaseAccountRecoveryStorage()
        private
        pure
        returns (BaseAccountRecoveryStorage storage _ars)
    {
        bytes32 slot_ = BASE_ACCOUNT_RECOVERY_STORAGE_SLOT;

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
    ) external override onlySelfOrTrustedExecutor {
        _addRecoveryProvider(provider_, recoveryData_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function removeRecoveryProvider(
        address provider_
    ) external override onlySelfOrTrustedExecutor {
        _removeRecoveryProvider(provider_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function recoverOwnership(
        address newTrustedExecutor_,
        address provider_,
        bytes memory proof_
    ) external override returns (bool) {
        _validateRecovery(newTrustedExecutor_, provider_, proof_);

        BaseAccountRecoveryStorage storage $ = _getBaseAccountRecoveryStorage();

        address oldTrustedExecutor_ = $.trustedExecutor;
        $.trustedExecutor = newTrustedExecutor_;

        emit OwnershipRecovered(oldTrustedExecutor_, newTrustedExecutor_);

        return true;
    }

    function getTrustedExecutor() public view returns (address) {
        return _getBaseAccountRecoveryStorage().trustedExecutor;
    }
}
