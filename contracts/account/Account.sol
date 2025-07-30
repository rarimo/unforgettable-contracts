// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SimpleAccount} from "@account-abstraction/contracts/accounts/SimpleAccount.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

import {IRecoveryManager} from "../interfaces/IRecoveryManager.sol";

contract Account is SimpleAccount, AAccountRecovery {
    using SafeERC20 for IERC20;

    constructor(IEntryPoint entryPoint_) SimpleAccount(entryPoint_) {}

    function initialize(address owner_) public override initializer {
        super.initialize(owner_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function addRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external override onlyOwner {
        (uint256 subscribeCost_, address paymentTokenAddr_) = IRecoveryManager(provider_)
            .getSubscribeCost(recoveryData_);

        if (paymentTokenAddr_ != address(0)) {
            IERC20(paymentTokenAddr_).safeTransferFrom(msg.sender, address(this), subscribeCost_);
            IERC20(paymentTokenAddr_).approve(provider_, subscribeCost_);
        }

        _addRecoveryProvider(provider_, recoveryData_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function removeRecoveryProvider(address provider_) external override onlyOwner {
        _removeRecoveryProvider(provider_);
    }

    /**
     * @inheritdoc AAccountRecovery
     */
    function recoverOwnership(
        address newOwner_,
        address provider_,
        bytes memory proof_
    ) external override returns (bool) {
        _validateRecovery(newOwner_, provider_, proof_);

        address oldOwner_ = owner;
        owner = newOwner_;

        emit OwnershipRecovered(oldOwner_, newOwner_);

        return true;
    }
}
