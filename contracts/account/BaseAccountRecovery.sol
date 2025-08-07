// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

contract BaseAccountRecovery is AAccountRecovery {
    address public trustedExecutor;

    error NotSelfOrTrustedExecutor(address account);

    modifier onlySelfOrTrustedExecutor() {
        require(
            msg.sender == address(this) || msg.sender == trustedExecutor,
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

        address oldTrustedExecutor_ = trustedExecutor;
        trustedExecutor = newTrustedExecutor_;

        emit OwnershipRecovered(oldTrustedExecutor_, newTrustedExecutor_);

        return true;
    }
}
