// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {AAccountRecovery} from "@solarity/solidity-lib/account-abstraction/AAccountRecovery.sol";

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

import {ISafe} from "../interfaces/safe/ISafe.sol";
import {IRecoveryManager} from "../interfaces/core/IRecoveryManager.sol";

/**
 * @notice The Unforgettable Safe Recovery module
 *
 * A Safe wallet module enabling ownership recovery via external recovery providers that implement
 * the IRecoveryManager interface.
 */
contract UnforgettableRecoveryModule is AAccountRecovery {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal constant SENTINEL_OWNERS = address(0x1);

    bytes32 public constant UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.safe.recovery.module.storage");

    address private immutable _moduleAddress;

    struct UnforgettableRecoveryModuleStorage {
        mapping(address => EnumerableSet.AddressSet) recoverableOwners;
        mapping(address => mapping(address => uint256)) recoveryMethodIds;
    }

    error NotADelegateCall();
    error RecoveryValidationFailed();
    error SwapOwnerCallFailed();
    error InvalidRecoveryMethodsLength();
    error NotASafeOwner(address owner);
    error InvalidOldOwner(address owner);

    modifier onlyDelegateCall() {
        _onlyDelegateCall();
        _;
    }

    constructor() {
        _moduleAddress = address(this);
    }

    /**
     * @notice A function to add a new recovery provider and register recoverable owners.
     *
     * @dev Must be executed via the Safe wallet delegate call.
     *
     * @param provider_ the address of an IRecoveryManager provider to add.
     * @param recoveryData_ Encoded owners array and recovery manager subscription data.
     */
    function addRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external payable override onlyDelegateCall {
        _addRecoveryProviderData(provider_, recoveryData_);
    }

    /**
     * @notice A function to remove an existing recovery provider and clear associated owners.
     *
     * @dev Must be executed via the Safe wallet delegate call.
     *
     * @param provider_ the address of a previously added recovery provider to remove.
     */
    function removeRecoveryProvider(address provider_) external payable override onlyDelegateCall {
        _removeRecoveryProviderData(provider_);
    }

    /**
     * @notice A function to update an existing recovery provider configuration.
     *
     * @dev Must be executed via the Safe wallet delegate call.
     * @dev Removes the current provider and adds it with new settings.
     *
     * @param provider_ the address of the IRecoveryManager provider to update.
     * @param recoveryData_ Encoded owners array and updated recovery manager subscription data.
     */
    function updateRecoveryProvider(
        address provider_,
        bytes memory recoveryData_
    ) external payable onlyDelegateCall {
        _removeRecoveryProviderData(provider_);

        _addRecoveryProviderData(provider_, recoveryData_);
    }

    /**
     * @notice A function to recover account access by swapping an owner in the Safe wallet.
     * @dev Under the hood, this invokes a Safe wallet delegate call to the module
     *      `validateRecoveryFromAccount` function. After the successful validation, it
     *      triggers a Safe module call to `swapOwner` via `execTransactionFromModule`,
     *      replacing the old owner with the new one.
     * @param subject_ Encoded recovery subject (account_, prevOwner_, oldOwner_, newOwner_).
     * @param provider_ the address of a provider verifying the recovery.
     * @param proof_ an encoded proof of recovery.
     * @return `true` if recovery is successful, `false` (or revert) otherwise.
     */
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
            to_: account_,
            value_: 0,
            data_: abi.encodeCall(ISafe.swapOwner, (prevOwner_, oldOwner_, newOwner_)),
            operation_: Enum.Operation.Call
        });

        require(success_, SwapOwnerCallFailed());

        return true;
    }

    /**
     * @notice A function to validate a recovery request.
     * @dev Must be executed via the Safe wallet delegate call because the module
     *      needs to read the recovery-related storage located in the Safe account.
     * @param object_ Encoded recovery object (account_, prevOwner_, oldOwner_, newOwner_).
     * @param provider_ the address of a provider verifying the recovery.
     * @param proof_ an encoded proof of recovery.
     */
    function validateRecoveryFromAccount(
        bytes memory object_,
        address provider_,
        bytes memory proof_
    ) external onlyDelegateCall {
        UnforgettableRecoveryModuleStorage storage $ = _getUnforgettableRecoveryModuleStorage();

        (, , address oldOwner_, ) = abi.decode(object_, (address, address, address, address));

        require(recoveryProviderAdded(provider_), ProviderNotRegistered(provider_));

        require($.recoverableOwners[provider_].contains(oldOwner_), InvalidOldOwner(oldOwner_));

        (address subscriptionManager_, bytes memory recoveryProof_) = abi.decode(
            proof_,
            (address, bytes)
        );

        uint256 recoveryMethodId_ = $.recoveryMethodIds[provider_][oldOwner_];

        recoveryProof_ = abi.encode(subscriptionManager_, recoveryMethodId_, recoveryProof_);

        IRecoveryManager(provider_).recover(object_, recoveryProof_);

        emit AccessRecovered(object_);
    }

    /**
     * @notice Retrieves the list of recoverable owners registered under a provider for a Safe account.
     * @dev Reads the `recoverableOwners` EnumerableSet directly from the Safe wallet
     *      storage using `getStorageAt`.
     * @param account_ the address of the Safe wallet where the recovery data is stored.
     * @param provider_ the address of the recovery provider whose recoverable owners are queried.
     * @return owners_ an array of owner addresses registered as recoverable under the provider.
     */
    function getRecoverableOwners(
        address account_,
        address provider_
    ) external view returns (address[] memory owners_) {
        bytes32 setSlot_ = keccak256(
            abi.encode(provider_, UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT)
        );

        bytes memory dataLength_ = ISafe(account_).getStorageAt(uint256(setSlot_), 1);
        uint256 ownersCount_ = abi.decode(dataLength_, (uint256));

        owners_ = new address[](ownersCount_);

        for (uint256 i = 0; i < ownersCount_; i++) {
            bytes32 elementSlot_ = keccak256(abi.encode(setSlot_));

            bytes memory elementData_ = ISafe(account_).getStorageAt(uint256(elementSlot_) + i, 1);

            owners_[i] = abi.decode(elementData_, (address));
        }
    }

    /**
     * @notice Returns the recovery method ID associated with a specific owner and provider.
     * @dev Reads the `recoveryMethodIds` nested mapping from the Safe wallet
     *      storage using `getStorageAt`.
     * @dev Each recoverable owner is assigned a unique method ID during provider registration.
     * @param account_ the address of the Safe wallet where the recovery data is stored.
     * @param provider_ the address of the recovery provider managing recovery for the owner.
     * @param owner_ the address of the Safe owner whose recovery method ID is queried.
     * @return the recovery method ID assigned to the owner for the specific provider.
     */
    function getRecoveryMethodId(
        address account_,
        address provider_,
        address owner_
    ) external view returns (uint256) {
        bytes32 innerSlot_ = keccak256(
            abi.encode(provider_, uint256(UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT) + 1)
        );
        bytes32 finalSlot_ = keccak256(abi.encode(owner_, innerSlot_));

        bytes memory methodId_ = ISafe(account_).getStorageAt(uint256(finalSlot_), 1);

        return abi.decode(methodId_, (uint256));
    }

    /**
     * @dev An internal function to add a new recovery provider and register recoverable owners.
     */
    function _addRecoveryProviderData(address provider_, bytes memory recoveryData_) internal {
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
            address owner_ = owners_[i];

            require(ISafe(address(this)).isOwner(owner_), NotASafeOwner(owner_));

            $.recoveryMethodIds[provider_][owner_] = i;
            $.recoverableOwners[provider_].add(owner_);
        }

        _addRecoveryProvider(provider_, subscribeRawData_, msg.value);
    }

    /**
     * @dev An internal function to remove an existing recovery provider and associated owners.
     */
    function _removeRecoveryProviderData(address provider_) internal {
        UnforgettableRecoveryModuleStorage storage $ = _getUnforgettableRecoveryModuleStorage();

        address[] memory owners_ = $.recoverableOwners[provider_].values();

        for (uint256 i = 0; i < owners_.length; i++) {
            delete $.recoveryMethodIds[provider_][owners_[i]];
        }

        $.recoverableOwners[provider_].clear();

        _removeRecoveryProvider(provider_, msg.value);
    }

    /// @inheritdoc AAccountRecovery
    function _validateRecovery(
        bytes memory object_,
        address provider_,
        bytes memory proof_
    ) internal override {
        (address account_, , , ) = abi.decode(object_, (address, address, address, address));

        bool success_ = ISafe(account_).execTransactionFromModule({
            to_: address(this),
            value_: 0,
            data_: abi.encodeCall(this.validateRecoveryFromAccount, (object_, provider_, proof_)),
            operation_: Enum.Operation.DelegateCall
        });

        require(success_, RecoveryValidationFailed());
    }

    /**
     * @dev Ensures the function is only called via a delegate call
     */
    function _onlyDelegateCall() internal view {
        require(address(this) != _moduleAddress, NotADelegateCall());
    }

    /**
     * @dev Returns a pointer to the storage namespace
     */
    function _getUnforgettableRecoveryModuleStorage()
        private
        pure
        returns (UnforgettableRecoveryModuleStorage storage _urms)
    {
        bytes32 slot_ = UNFORGETTABLE_RECOVERY_MODULE_STORAGE_SLOT;

        assembly {
            _urms.slot := slot_
        }
    }
}
