// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Account} from "../../account/Account.sol";

contract AccountMock is Account {
    constructor(address trustedExecutor_) {
        _getBaseAccountRecoveryMockStorage().trustedExecutor = trustedExecutor_;
    }

    function _getBaseAccountRecoveryMockStorage()
        private
        pure
        returns (BaseAccountRecoveryStorage storage _ars)
    {
        bytes32 slot_ = BASE_ACCOUNT_RECOVERY_STORAGE_SLOT;

        assembly {
            _ars.slot := slot_
        }
    }
}
