// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title IHelperDataFactory
 * @notice Interface for managing helper data factory operations.
 *         Manages registration of accounts, helper data parts submission,
 *         and metadata/subscription tracking.
 * @dev Supports querying accounts by status, metadata filters, and pagination.
 */
interface IHelperDataFactory {
    /**
     * @notice Enumeration for account subscription status.
     * @param NONE The account not registered or subscription cleared.
     * @param ACTIVE The account subscription is currently valid.
     * @param EXPIRED The account subscription has expired.
     */
    enum AccountStatus {
        NONE,
        ACTIVE,
        EXPIRED
    }

    /**
     * @notice Basic account information.
     * @param account The account's address.
     * @param subscriptionEndTime Timestamp when the subscription ends.
     * @param metadata Custom metadata associated with the account.
     */
    struct AccountInfo {
        address account;
        uint64 subscriptionEndTime;
        bytes32 metadata;
    }

    /**
     * @notice Complete account data including helper data parts mapping.
     * @param subscriptionEndTime Timestamp when the subscription ends.
     * @param metadata Custom metadata associated with the account.
     * @param helperDataParts Mapping of part indices to helper data part addresses.
     */
    struct AccountData {
        uint64 subscriptionEndTime;
        bytes32 metadata;
        EnumerableMap.UintToAddressMap helperDataParts;
    }

    /**
     * @notice Thrown when attempting to add a helper data manager that already exists.
     * @param manager The address that is already a helper data manager.
     */
    error HelperDataManagerAlreadyAdded(address manager);

    /**
     * @notice Thrown when an operation expects a helper data manager but the address is not one.
     * @param manager The address that is not a helper data manager.
     */
    error NotAHelperDataManager(address manager);

    /**
     * @notice Thrown when attempting to set a helper data index that is already set for an account.
     * @param account The account address.
     * @param partIndex The helper data part index that is already set.
     */
    error HelperDataIndexAlreadySet(address account, uint256 partIndex);

    /**
     * @notice Thrown when attempting to register an account that is already registered.
     * @param account The account address that is already registered.
     */
    error AccountAlreadyRegistered(address account);

    /**
     * @notice Thrown when attempting to access an account that is not registered.
     * @param account The account address that is not registered.
     */
    error NotARegisteredAccount(address account);

    /**
     * @notice Emitted when a new helper data manager is added.
     * @param manager The address added as a helper data manager.
     */
    event HelperDataManagerAdded(address manager);

    /**
     * @notice Emitted when a helper data manager is removed.
     * @param manager The address removed from helper data managers.
     */
    event HelperDataManagerRemoved(address manager);

    /**
     * @notice Emitted when an account is registered in the factory.
     * @param account The address of the registered account.
     */
    event AccountRegistered(address indexed account);

    /**
     * @notice Emitted when an account's metadata is updated.
     * @param account The address of the account.
     * @param newMetadata The new metadata value.
     */
    event AccountMetadataUpdated(address indexed account, bytes32 newMetadata);

    /**
     * @notice Emitted when an account's subscription end time is updated.
     * @param account The address of the account.
     * @param newSubscriptionEndTime The new subscription end timestamp.
     */
    event AccountSubscriptionEndTimeUpdated(
        address indexed account,
        uint64 newSubscriptionEndTime
    );

    /**
     * @notice Emitted when a helper data part is submitted for an account.
     * @param account The address of the account.
     * @param partIndex The index of the helper data part.
     * @param partPointer The deployed address of the helper data contract.
     */
    event HelperDataPartSubmitted(address indexed account, uint256 partIndex, address partPointer);

    /**
     * @notice Adds one or more addresses as authorized helper data managers.
     * @param managersToAdd_ Array of addresses to register as helper data managers.
     */
    function addHelperDataManagers(address[] calldata managersToAdd_) external;

    /**
     * @notice Removes one or more addresses from the helper data manager list.
     * @param managersToRemove_ Array of addresses to remove from managers.
     */
    function removeHelperDataManagers(address[] calldata managersToRemove_) external;

    /**
     * @notice Registers a new account with initial helper data and metadata.
     * @param account_ Address of the account to register.
     * @param partIndex_ Index for the initial helper data part.
     * @param subscriptionEndTime_ Unix timestamp when the account subscription ends.
     * @param metadata_ Custom metadata value for the account.
     * @param data_ Encoded data to be processed by the helper data manager.
     * @return The deployed address of the helper data contract for the given part.
     */
    function registerAccount(
        address account_,
        uint256 partIndex_,
        uint64 subscriptionEndTime_,
        bytes32 metadata_,
        bytes memory data_
    ) external returns (address);

    /**
     * @notice Updates the metadata for a registered account.
     * @param account_ Address of the account to update.
     * @param newMetadata_ New metadata value.
     */
    function updateAccountMetadata(address account_, bytes32 newMetadata_) external;

    /**
     * @notice Sets the subscription end time for a registered account.
     * @param account_ Address of the account to update.
     * @param newEndTime_ New Unix timestamp for subscription end.
     */
    function updateAccountSubscriptionEndTime(address account_, uint64 newEndTime_) external;

    /**
     * @notice Increases the subscription end time by a specified amount.
     * @param account_ Address of the account to update.
     * @param amountToIncrease_ Number of seconds to add to the current subscription end time.
     */
    function increaseAccountSubscriptionEndTime(
        address account_,
        uint64 amountToIncrease_
    ) external;

    /**
     * @notice Submits a new helper data part for an existing account.
     * @param account_ Address of the account.
     * @param partIndex_ Unique index for this helper data part.
     * @param data_ Encoded data to be processed by the helper data manager.
     * @return The deployed address of the helper data contract for this part.
     */
    function submitHelperDataPart(
        address account_,
        uint256 partIndex_,
        bytes memory data_
    ) external returns (address);

    /**
     * @notice Returns the list of currently authorized helper data managers.
     * @return An array of helper data manager addresses.
     */
    function getHelperDataManagers() external view returns (address[] memory);

    /**
     * @notice Returns the total count of registered accounts.
     * @return The number of accounts registered in the factory.
     */
    function getRegisteredAccountsCount() external view returns (uint256);

    /**
     * @notice Returns all registered account addresses.
     * @return An array of all registered account addresses.
     */
    function getRegisteredAccounts() external view returns (address[] memory);

    /**
     * @notice Returns registered accounts filtered by subscription status and metadata.
     * @param status_ Filter by `AccountStatus` (NONE, ACTIVE, or EXPIRED).
     * @param metadata_ Filter by metadata value (pass 0 to match any metadata).
     * @return An array of matching account addresses.
     */
    function getRegisteredAccountsWithFilters(
        AccountStatus status_,
        bytes32 metadata_
    ) external view returns (address[] memory);

    /**
     * @notice Returns the count of helper data parts for an account.
     * @param account_ Address of the account.
     * @return The number of helper data parts registered for this account.
     */
    function getHelperDataPartsCount(address account_) external view returns (uint256);

    /**
     * @notice Returns all helper data contract addresses for an account.
     * @param account_ Address of the account.
     * @return pointers_ An array of helper data contract addresses.
     */
    function getHelperDataPointers(
        address account_
    ) external view returns (address[] memory pointers_);

    /**
     * @notice Retrieves the account information snapshot.
     * @param account_ Address of the account.
     * @return An `AccountInfo` struct containing the account's current state.
     */
    function getAccountInfo(address account_) external view returns (AccountInfo memory);

    /**
     * @notice Reads data from multiple helper data contract pointers.
     * @param pointers_ Array of helper data contract addresses to read from.
     * @return pointersData_ An array of bytes data returned from each pointer.
     */
    function readPointersData(
        address[] calldata pointers_
    ) external view returns (bytes[] memory pointersData_);

    /**
     * @notice Returns the implementation address for upgradeable contracts.
     * @return The implementation contract address.
     */
    function implementation() external view returns (address);

    /**
     * @notice Returns filtered and paginated registered accounts.
     * @param status_ Filter by `AccountStatus` (NONE, ACTIVE, or EXPIRED).
     * @param metadata_ Filter by metadata value (pass 0 to match any metadata).
     * @param offset_ Number of records to skip from the start.
     * @param limit_ Maximum number of records to return.
     * @return An array of matching account addresses.
     */
    function getRegisteredAccountsWithFiltersPaginated(
        AccountStatus status_,
        bytes32 metadata_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    /**
     * @notice Returns paginated registered accounts.
     * @param offset_ Number of records to skip from the start.
     * @param limit_ Maximum number of records to return.
     * @return An array of account addresses.
     */
    function getRegisteredAccountsPaginated(
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    /**
     * @notice Returns paginated helper data pointers for an account.
     * @param account_ Address of the account.
     * @param offset_ Number of records to skip from the start.
     * @param limit_ Maximum number of records to return.
     * @return pointers_ An array of helper data contract addresses.
     */
    function getHelperDataPointersPaginated(
        address account_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory pointers_);

    /**
     * @notice Checks whether `manager_` is an authorized helper data manager.
     * @param manager_ Address to check for manager status.
     * @return True if `manager_` is a registered helper data manager, otherwise false.
     */
    function isHelperDataManager(address manager_) external view returns (bool);

    /**
     * @notice Checks whether `account_` is a registered account.
     * @param account_ Address to check for registration status.
     * @return True if `account_` is registered in the factory, otherwise false.
     */
    function isAccountRegistered(address account_) external view returns (bool);

    /**
     * @notice Returns the current subscription status of an account.
     * @dev Returns `NONE` if account is not registered, `ACTIVE` if current time
     *      is before subscription end time, and `EXPIRED` if past subscription end time.
     * @param account_ Address of the account.
     * @return The `AccountStatus` of the account.
     */
    function getAccountStatus(address account_) external view returns (AccountStatus);
}
