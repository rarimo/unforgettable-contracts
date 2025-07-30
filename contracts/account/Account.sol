// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

import {Simple7702Account} from "./Simple7702Account.sol";

import {IRecoveryManager} from "../interfaces/IRecoveryManager.sol";

contract Account is Simple7702Account, AAccountRecovery {
    using SafeERC20 for IERC20;

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
