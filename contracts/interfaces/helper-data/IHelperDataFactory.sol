// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

interface IHelperDataFactory {
    enum AccountStatus {
        NONE,
        ACTIVE,
        EXPIRED
    }

    struct AccountInfo {
        address account;
        uint64 subscriptionEndTime;
        bytes32 metadata;
    }

    struct AccountData {
        uint64 subscriptionEndTime;
        bytes32 metadata;
        EnumerableMap.UintToAddressMap helperDataParts;
    }

    error HelperDataManagerAlreadyAdded(address manager);
    error NotAHelperDataManager(address manager);
    error HelperDataIndexAlreadySet(address account, uint256 partIndex);
    error AccountAlreadyRegistered(address account);
    error NotARegisteredAccount(address account);

    event HelperDataManagerAdded(address manager);
    event HelperDataManagerRemoved(address manager);
    event AccountRegistered(address indexed account);
    event AccountMetadataUpdated(address indexed account, bytes32 newMetadata);
    event AccountSubscriptionEndTimeUpdated(
        address indexed account,
        uint64 newSubscriptionEndTime
    );
    event HelperDataPartSubmitted(address indexed account, uint256 partIndex, address partPointer);

    function addHelperDataManagers(address[] calldata managersToAdd_) external;

    function removeHelperDataManagers(address[] calldata managersToRemove_) external;

    function registerAccount(
        address account_,
        uint256 partIndex_,
        uint64 subscriptionEndTime_,
        bytes32 metadata_,
        bytes memory data_
    ) external returns (address);

    function updateAccountMetadata(address account_, bytes32 newMetadata_) external;

    function updateAccountSubscriptionEndTime(address account_, uint64 newEndTime_) external;

    function increaseAccountSubscriptionEndTime(
        address account_,
        uint64 amountToIncrease_
    ) external;

    function submitHelperDataPart(
        address account_,
        uint256 partIndex_,
        bytes memory data_
    ) external returns (address);

    function getHelperDataManagers() external view returns (address[] memory);

    function getRegisteredAccountsCount() external view returns (uint256);

    function getRegisteredAccounts() external view returns (address[] memory);

    function getRegisteredAccountsWithFilters(
        AccountStatus status_,
        bytes32 metadata_
    ) external view returns (address[] memory);

    function getHelperDataPartsCount(address account_) external view returns (uint256);

    function getHelperDataPointers(
        address account_
    ) external view returns (address[] memory pointers_);

    function readPointersData(
        address[] calldata pointers_
    ) external view returns (bytes[] memory pointersData_);

    function getRegisteredAccountsWithFiltersPaginated(
        AccountStatus status_,
        bytes32 metadata_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    function getRegisteredAccountsPaginated(
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory);

    function getHelperDataPointersPaginated(
        address account_,
        uint256 offset_,
        uint256 limit_
    ) external view returns (address[] memory pointers_);

    function isHelperDataManager(address manager_) external view returns (bool);

    function isAccountRegistered(address account_) external view returns (bool);

    function getAccountStatus(address account_) external view returns (AccountStatus);
}
