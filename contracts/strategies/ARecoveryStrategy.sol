// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

import {IRecoveryStrategy} from "../interfaces/strategies/IRecoveryStrategy.sol";

abstract contract ARecoveryStrategy is IRecoveryStrategy, NoncesUpgradeable {
    bytes32 public constant A_RECOVERY_STRATEGY_STORAGE_SLOT =
        keccak256("unforgettable.contract.abstract.recovery.strategy.storage");

    struct ARecoveryStrategyStorage {
        address recoveryManagerAddr;
    }

    error NotARecoveryManager(address account);

    modifier onlyRecoveryManager() {
        _onlyRecoveryManager();
        _;
    }

    function _getARecoveryStrategyStorage()
        private
        pure
        returns (ARecoveryStrategyStorage storage _arss)
    {
        bytes32 slot_ = A_RECOVERY_STRATEGY_STORAGE_SLOT;

        assembly {
            _arss.slot := slot_
        }
    }

    function __ARecoveryStrategy_init(address recoveryManagerAddr_) internal onlyInitializing {
        _getARecoveryStrategyStorage().recoveryManagerAddr = recoveryManagerAddr_;
    }

    function recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryData_
    ) external onlyRecoveryManager {
        _recoverAccount(account_, object_, recoveryData_);
    }

    function getRecoveryManager() external view returns (address) {
        return _getARecoveryStrategyStorage().recoveryManagerAddr;
    }

    function validateAccountRecoveryData(bytes memory recoveryData_) external view {
        _validateAccountRecoveryData(recoveryData_);
    }

    function _recoverAccount(
        address account_,
        bytes memory object_,
        bytes memory recoveryData_
    ) internal virtual;

    function _validateAccountRecoveryData(bytes memory recoveryData_) internal view virtual;

    function _onlyRecoveryManager() internal view {
        require(
            msg.sender == _getARecoveryStrategyStorage().recoveryManagerAddr,
            NotARecoveryManager(msg.sender)
        );
    }
}
