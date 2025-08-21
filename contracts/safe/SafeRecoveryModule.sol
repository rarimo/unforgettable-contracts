// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IAccountRecovery} from "@solarity/solidity-lib/interfaces/account-abstraction/IAccountRecovery.sol";
import {IRecoveryProvider} from "@solarity/solidity-lib/interfaces/account-abstraction/IRecoveryProvider.sol";

import {Enum} from "./common/Enum.sol";

import {ISafe} from "../interfaces/safe/ISafe.sol";
import {IRecoveryManager} from "../interfaces/IRecoveryManager.sol";

contract SafeRecoveryModule is IAccountRecovery {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal constant SENTINEL_OWNERS = address(0x1);

    bytes32 public constant SAFE_RECOVERY_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.safe.recovery.module.storage");

    struct SafeRecoveryModuleStorage {
        EnumerableSet.AddressSet recoveryProviders;
        mapping(address => mapping(address => uint256)) recoveryMethodIds;
    }

    event RecoveryProviderAdded(address indexed account, address indexed provider);
    event RecoveryProviderRemoved(address indexed account, address indexed provider);

    error ZeroAddress();
    error ProviderAlreadyAdded(address account, address provider);
    error ProviderNotRegistered(address account, address provider);
    error InvalidRecoveryMethodsLength();
    error RecoverCallFailed();
    error SwapOwnerCallFailed();
    error InvalidOwner(address account, address owner);

    function _getSafeRecoveryModuleStorage()
        private
        pure
        returns (SafeRecoveryModuleStorage storage _srms)
    {
        bytes32 slot_ = SAFE_RECOVERY_MODULE_STORAGE_SLOT;

        assembly {
            _srms.slot := slot_
        }
    }

    function addRecoveryProvider(address provider_, bytes memory recoveryData_) external payable {
        _addRecoveryProvider(provider_, recoveryData_);
    }

    function removeRecoveryProvider(address provider_) external payable {
        _removeRecoveryProvider(provider_);
    }

    function recoverAccess(
        bytes memory subject_,
        address provider_,
        bytes memory proof_
    ) external returns (bool) {
        _validateRecovery(subject_, provider_, proof_);

        (address account_, address oldOwner_, address newOwner_) = abi.decode(
            subject_,
            (address, address, address)
        );

        address prevOwner_ = _findPrevOwner(account_, oldOwner_);

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
    ) external {
        (address account_, address oldOwner_, ) = abi.decode(object_, (address, address, address));

        require(recoveryProviderAdded(provider_), ProviderNotRegistered(account_, provider_));

        (address subscriptionManager_, bytes memory recoveryProof_) = abi.decode(
            proof_,
            (address, bytes)
        );

        uint256 recoveryMethodId_ = _getSafeRecoveryModuleStorage().recoveryMethodIds[provider_][
            oldOwner_
        ];

        recoveryProof_ = abi.encode(subscriptionManager_, recoveryMethodId_, recoveryProof_);

        IRecoveryProvider(provider_).recover(object_, recoveryProof_);
    }

    function recoveryProviderAdded(address provider_) public view returns (bool) {
        SafeRecoveryModuleStorage storage $ = _getSafeRecoveryModuleStorage();

        return $.recoveryProviders.contains(provider_);
    }

    function getRecoveryProviders() public view returns (address[] memory) {
        SafeRecoveryModuleStorage storage $ = _getSafeRecoveryModuleStorage();

        return $.recoveryProviders.values();
    }

    function _addRecoveryProvider(address provider_, bytes memory recoveryData_) internal {
        if (provider_ == address(0)) revert ZeroAddress();

        SafeRecoveryModuleStorage storage $ = _getSafeRecoveryModuleStorage();

        if (!$.recoveryProviders.add(provider_))
            revert ProviderAlreadyAdded(address(this), provider_);

        address[] memory owners_ = ISafe(address(this)).getOwners();

        IRecoveryManager.SubscribeData memory subscribeData_ = abi.decode(
            recoveryData_,
            (IRecoveryManager.SubscribeData)
        );

        uint256 recoveryMethodsCount_ = subscribeData_.recoveryMethods.length;

        require(owners_.length == recoveryMethodsCount_, InvalidRecoveryMethodsLength());

        for (uint256 i = 0; i < recoveryMethodsCount_; i++) {
            $.recoveryMethodIds[provider_][owners_[i]] = i;
        }

        IRecoveryProvider(provider_).subscribe(recoveryData_);

        emit RecoveryProviderAdded(address(this), provider_);
    }

    function _removeRecoveryProvider(address provider_) internal {
        SafeRecoveryModuleStorage storage $ = _getSafeRecoveryModuleStorage();

        if (!$.recoveryProviders.remove(provider_))
            revert ProviderNotRegistered(address(this), provider_);

        address[] memory owners_ = ISafe(address(this)).getOwners();

        for (uint256 i = 0; i < owners_.length; i++) {
            delete $.recoveryMethodIds[provider_][owners_[i]];
        }

        IRecoveryProvider(provider_).unsubscribe();

        emit RecoveryProviderRemoved(address(this), provider_);
    }

    function _validateRecovery(
        bytes memory object_,
        address provider_,
        bytes memory proof_
    ) internal {
        (address account_, , ) = abi.decode(object_, (address, address, address));

        bool success_ = ISafe(account_).execTransactionFromModule({
            to: address(this),
            value: 0,
            data: abi.encodeCall(this.validateRecoveryFromAccount, (object_, provider_, proof_)),
            operation: Enum.Operation.DelegateCall
        });

        require(success_, RecoverCallFailed());
    }

    function _findPrevOwner(
        address account_,
        address owner_
    ) internal view returns (address prevOwner_) {
        address[] memory owners_ = ISafe(account_).getOwners();

        prevOwner_ = SENTINEL_OWNERS;

        for (uint256 i = 0; i < owners_.length; i++) {
            if (owners_[i] == owner_) {
                return prevOwner_;
            }

            prevOwner_ = owners_[i];
        }

        revert InvalidOwner(account_, owner_);
    }
}
