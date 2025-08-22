// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";
import {IRecoveryProvider} from "@solarity/solidity-lib/interfaces/account-abstraction/IRecoveryProvider.sol";

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

import {ISafe} from "../interfaces/safe/ISafe.sol";
import {IRecoveryManager} from "../interfaces/core/IRecoveryManager.sol";

contract UnforgettableRecoveryModule is AAccountRecovery {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal constant SENTINEL_OWNERS = address(0x1);

    bytes32 public constant UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.safe.recovery.module.storage");

    struct UnforgettableRecoveryModuleStorage {
        address moduleAddress;
        mapping(address => EnumerableSet.AddressSet) recoverableOwners;
        mapping(address => mapping(address => uint256)) recoveryMethodIds;
    }

    error NotADelegateCall();
    error RecoverCallFailed();
    error SwapOwnerCallFailed();
    error InvalidRecoveryMethodsLength();
    error InvalidOldOwner(address owner);

    modifier onlyDelegateCall() {
        require(
            address(this) != _getUnforgettableRecoveryModuleStorage().moduleAddress,
            NotADelegateCall()
        );
        _;
    }

    constructor() {
        _getUnforgettableRecoveryModuleStorage().moduleAddress = address(this);
    }

    function _getUnforgettableRecoveryModuleStorage()
        private
        pure
        returns (UnforgettableRecoveryModuleStorage storage _srms)
    {
        bytes32 slot_ = UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT;

        assembly {
            _srms.slot := slot_
        }
    }

    function addRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external payable override onlyDelegateCall {
        (address[] memory owners_, bytes memory subscribeRawData_) = abi.decode(
            recoveryData_,
            (address[], bytes)
        );

        IRecoveryManager.SubscribeData memory subscribeData_ = abi.decode(
            subscribeRawData_,
            (IRecoveryManager.SubscribeData)
        );

        uint256 recoveryMethodsCount_ = subscribeData_.recoveryMethods.length;

        require(owners_.length == recoveryMethodsCount_, InvalidRecoveryMethodsLength());

        UnforgettableRecoveryModuleStorage storage $ = _getUnforgettableRecoveryModuleStorage();

        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            $.recoveryMethodIds[provider_][owners_[i]] = i;

            $.recoverableOwners[provider_].add(owners_[i]);
        }

        _addRecoveryProvider(provider_, subscribeRawData_);
    }

    function removeRecoveryProvider(address provider_) external payable override onlyDelegateCall {
        UnforgettableRecoveryModuleStorage storage $ = _getUnforgettableRecoveryModuleStorage();

        address[] memory owners_ = $.recoverableOwners[provider_].values();

        for (uint256 i = 0; i < owners_.length; i++) {
            delete $.recoveryMethodIds[provider_][owners_[i]];
        }

        $.recoverableOwners[provider_].clear();

        _removeRecoveryProvider(provider_);
    }

    function recoverAccess(
        bytes memory subject_,
        address provider_,
        bytes memory proof_
    ) external override returns (bool) {
        _validateRecovery(subject_, provider_, proof_);

        (address account_, address prevOwner_, address oldOwner_, address newOwner_) = abi.decode(
            subject_,
            (address, address, address, address)
        );

        bool success_ = ISafe(account_).execTransactionFromModule({
            to: account_,
            value: 0,
            data: abi.encodeCall(ISafe.swapOwner, (prevOwner_, oldOwner_, newOwner_)),
            operation: Enum.Operation.Call
        });

        require(success_, SwapOwnerCallFailed());

        emit AccessRecovered(subject_);

        return true;
    }

    function validateRecoveryFromAccount(
        bytes memory object_,
        address provider_,
        bytes memory proof_
    ) external onlyDelegateCall {
        UnforgettableRecoveryModuleStorage storage $ = _getUnforgettableRecoveryModuleStorage();

        (, , address oldOwner_, ) = abi.decode(object_, (address, address, address, address));

        require($.recoverableOwners[provider_].contains(oldOwner_), InvalidOldOwner(oldOwner_));

        require(recoveryProviderAdded(provider_), ProviderNotRegistered(provider_));

        (address subscriptionManager_, bytes memory recoveryProof_) = abi.decode(
            proof_,
            (address, bytes)
        );

        uint256 recoveryMethodId_ = $.recoveryMethodIds[provider_][oldOwner_];

        recoveryProof_ = abi.encode(subscriptionManager_, recoveryMethodId_, recoveryProof_);

        IRecoveryProvider(provider_).recover(object_, recoveryProof_);
    }

    function _validateRecovery(
        bytes memory object_,
        address provider_,
        bytes memory proof_
    ) internal override {
        (address account_, , , ) = abi.decode(object_, (address, address, address, address));

        bool success_ = ISafe(account_).execTransactionFromModule({
            to: address(this),
            value: 0,
            data: abi.encodeCall(this.validateRecoveryFromAccount, (object_, provider_, proof_)),
            operation: Enum.Operation.DelegateCall
        });

        require(success_, RecoverCallFailed());
    }
}
