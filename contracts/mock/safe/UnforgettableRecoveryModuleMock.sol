// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {UnforgettableRecoveryModule} from "../../safe/UnforgettableRecoveryModule.sol";

contract UnforgettableRecoveryModuleMock is UnforgettableRecoveryModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    event RecoverableOwners(address[] owners);
    event RecoveryMethodIds(uint256[] ids);

    function getRecoverableOwners(address provider_) external {
        address[] memory owners_ = _getUnforgettableRecoveryModuleMockStorage()
            .recoverableOwners[provider_]
            .values();

        emit RecoverableOwners(owners_);
    }

    function getRecoveryMethodIds(address provider_) external {
        UnforgettableRecoveryModuleStorage
            storage $ = _getUnforgettableRecoveryModuleMockStorage();

        address[] memory owners_ = $.recoverableOwners[provider_].values();

        uint256[] memory ids_ = new uint256[](owners_.length);

        for (uint256 i = 0; i < owners_.length; i++) {
            ids_[i] = $.recoveryMethodIds[provider_][owners_[i]];
        }

        emit RecoveryMethodIds(ids_);
    }

    function _getUnforgettableRecoveryModuleMockStorage()
        private
        pure
        returns (UnforgettableRecoveryModuleStorage storage _srms)
    {
        bytes32 slot_ = UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT;

        assembly {
            _srms.slot := slot_
        }
    }
}
