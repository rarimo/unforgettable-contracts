// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Account} from "../../accounts/Account.sol";

contract AccountMock is Account {
    constructor(address trustedExecutor_) {
        _getBaseAccountRecoveryMockStorage().trustedExecutor = trustedExecutor_;
    }

    function _getBaseAccountRecoveryMockStorage()
        private
        pure
        returns (Base7702AccountRecoveryStorage storage _ars)
    {
        bytes32 slot_ = BASE_7702_ACCOUNT_RECOVERY_STORAGE_SLOT;

        assembly {
            _ars.slot := slot_
        }
    }
}
