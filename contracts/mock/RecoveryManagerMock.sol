// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {RecoveryManager} from "../RecoveryManager.sol";

contract RecoveryManagerMock is RecoveryManager {
    function getSubscriptionManager(address account_) external view returns (address) {
        return _getRecoveryManagerMockStorage().accountsRecoveryData[account_].subscriptionManager;
    }

    function getRecoveryMethod(address account_) external view returns (RecoveryMethod memory) {
        return _getRecoveryManagerMockStorage().accountsRecoveryData[account_].recoveryMethod;
    }

    function _getRecoveryManagerMockStorage()
        private
        pure
        returns (RecoveryManagerStorage storage _rms)
    {
        bytes32 slot_ = RECOVERY_MANAGER_STORAGE_SLOT;

        assembly {
            _rms.slot := slot_
        }
    }
}
