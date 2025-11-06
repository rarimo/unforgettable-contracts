// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";
import {Paginator} from "@solarity/solidity-lib/libs/arrays/Paginator.sol";
import {Vector} from "@solarity/solidity-lib/libs/data-structures/memory/Vector.sol";

import {IHelperDataFactory} from "../interfaces/helper-data/IHelperDataFactory.sol";

contract HelperDataFactory is
    IHelperDataFactory,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ADeployerGuard
{
    using Paginator for *;
    using EnumerableSet for *;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Vector for Vector.AddressVector;

    bytes32 private constant HELPER_DATA_FACTORY_STORAGE_SLOT =
        keccak256("unforgettable.contract.helper.data.helper.data.factory.storage");

    struct HelperDataFactoryStorage {
        EnumerableSet.AddressSet helperDataManagers;
        EnumerableSet.AddressSet registeredAccounts;
        mapping(address => AccountData) accountsData;
    }

    modifier onlyHelperDataManager() {
        _checkHelperDataManager(msg.sender);
        _;
    }

    modifier onlyRegisteredAccount(address account_) {
        _onlyRegisteredAccount(account_);
        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getHelperDataFactoryStorage()
        private
        pure
        returns (HelperDataFactoryStorage storage _hdfs)
    {
        bytes32 slot_ = HELPER_DATA_FACTORY_STORAGE_SLOT;

        assembly ("memory-safe") {
            _hdfs.slot := slot_
        }
    }

    function initialize(address[] calldata initialManagers_) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _addHelperDataManagers(initialManagers_);
    }

    function addHelperDataManagers(address[] calldata managersToAdd_) external onlyOwner {
        _addHelperDataManagers(managersToAdd_);
    }

    function removeHelperDataManagers(address[] calldata managersToRemove_) external onlyOwner {
        _removeHelperDataManagers(managersToRemove_);
    }

    function registerAccount(
        address account_,
        uint256 partIndex_,
        uint64 subscriptionEndTime_,
        bytes32 metadata_,
        bytes memory data_
    ) external onlyHelperDataManager returns (address) {
        _registerAccount(account_, subscriptionEndTime_, metadata_);

        return _submitHelperDataPart(account_, partIndex_, data_);
    }

    function updateAccountMetadata(
        address account_,
        bytes32 newMetadata_
    ) external onlyHelperDataManager onlyRegisteredAccount(account_) {
        _updateAccountMetadata(account_, newMetadata_);
    }

    function updateAccountSubscriptionEndTime(
        address account_,
        uint64 newEndTime_
    ) external onlyHelperDataManager onlyRegisteredAccount(account_) {
        _updateAccountSubscriptionEndTime(account_, newEndTime_);
    }

    function increaseAccountSubscriptionEndTime(
        address account_,
        uint64 amountToIncrease_
    ) external onlyHelperDataManager onlyRegisteredAccount(account_) {
        uint64 newEndTime_ = _getHelperDataFactoryStorage()
            .accountsData[account_]
            .subscriptionEndTime + amountToIncrease_;

        _updateAccountSubscriptionEndTime(account_, newEndTime_);
    }

    function submitHelperDataPart(
        address account_,
        uint256 partIndex_,
        bytes memory data_
    ) external onlyHelperDataManager returns (address) {
        return _submitHelperDataPart(account_, partIndex_, data_);
    }

    function getHelperDataManagers() external view returns (address[] memory) {
        return _getHelperDataFactoryStorage().helperDataManagers.values();
    }

    function getRegisteredAccountsCount() external view returns (uint256) {
        return _getHelperDataFactoryStorage().registeredAccounts.length();
    }

    function getRegisteredAccounts() external view returns (address[] memory) {
        return getRegisteredAccountsPaginated(0, type(uint256).max);
    }

    function getRegisteredAccountsWithFilters(
        AccountStatus status_,
        bytes32 metadata_
    ) external view returns (address[] memory) {
        return getRegisteredAccountsWithFiltersPaginated(status_, metadata_, 0, type(uint256).max);
    }

    function getHelperDataPartsCount(address account_) external view returns (uint256) {
        return _getHelperDataFactoryStorage().accountsData[account_].helperDataParts.length();
    }

    function getHelperDataPointers(address account_) external view returns (address[] memory) {
        return getHelperDataPointersPaginated(account_, 0, type(uint256).max);
    }

    function readPointersData(
        address[] calldata pointers_
    ) external view returns (bytes[] memory pointersData_) {
        pointersData_ = new bytes[](pointers_.length);

        for (uint256 i = 0; i < pointers_.length; ++i) {
            pointersData_[i] = SSTORE2.read(pointers_[i]);
        }
    }

    function getRegisteredAccountsWithFiltersPaginated(
        AccountStatus status_,
        bytes32 metadata_,
        uint256 offset_,
        uint256 limit_
    ) public view returns (address[] memory) {
        address[] memory registeredAccounts_ = getRegisteredAccountsPaginated(offset_, limit_);
        Vector.AddressVector memory filteredAccounts_ = Vector.newAddress();

        for (uint256 i = 0; i < registeredAccounts_.length; ++i) {
            AccountData storage accountData = _getHelperDataFactoryStorage().accountsData[
                registeredAccounts_[i]
            ];

            if (
                getAccountStatus(registeredAccounts_[i]) == status_ &&
                (metadata_ == 0 || metadata_ == accountData.metadata)
            ) {
                filteredAccounts_.push(registeredAccounts_[i]);
            }
        }

        return filteredAccounts_.toArray();
    }

    function getRegisteredAccountsPaginated(
        uint256 offset_,
        uint256 limit_
    ) public view returns (address[] memory) {
        return _getHelperDataFactoryStorage().registeredAccounts.part(offset_, limit_);
    }

    function getHelperDataPointersPaginated(
        address account_,
        uint256 offset_,
        uint256 limit_
    ) public view returns (address[] memory pointers_) {
        AccountData storage accountData = _getHelperDataFactoryStorage().accountsData[account_];

        uint256[] memory allIndexes_ = accountData.helperDataParts.keys();
        uint256 to_ = Paginator.getTo(allIndexes_.length, offset_, limit_);

        pointers_ = new address[](to_ - offset_);

        for (uint256 i = offset_; i < to_; ++i) {
            pointers_[i - offset_] = accountData.helperDataParts.get(allIndexes_[i]);
        }
    }

    function isHelperDataManager(address manager_) public view returns (bool) {
        return _getHelperDataFactoryStorage().helperDataManagers.contains(manager_);
    }

    function isAccountRegistered(address account_) public view returns (bool) {
        return _getHelperDataFactoryStorage().registeredAccounts.contains(account_);
    }

    function getAccountStatus(address account_) public view returns (AccountStatus) {
        AccountData storage accountData = _getHelperDataFactoryStorage().accountsData[account_];

        uint64 endTime = accountData.subscriptionEndTime;

        if (endTime == 0) {
            return AccountStatus.NONE;
        } else if (endTime >= block.timestamp) {
            return AccountStatus.ACTIVE;
        } else {
            return AccountStatus.EXPIRED;
        }
    }

    function _addHelperDataManagers(address[] calldata managersToAdd_) internal {
        HelperDataFactoryStorage storage $ = _getHelperDataFactoryStorage();

        for (uint256 i = 0; i < managersToAdd_.length; ++i) {
            require(
                $.helperDataManagers.add(managersToAdd_[i]),
                HelperDataManagerAlreadyAdded(managersToAdd_[i])
            );

            emit HelperDataManagerAdded(managersToAdd_[i]);
        }
    }

    function _removeHelperDataManagers(address[] calldata managersToRemove_) internal {
        HelperDataFactoryStorage storage $ = _getHelperDataFactoryStorage();

        for (uint256 i = 0; i < managersToRemove_.length; ++i) {
            require(
                $.helperDataManagers.remove(managersToRemove_[i]),
                NotAHelperDataManager(managersToRemove_[i])
            );

            emit HelperDataManagerRemoved(managersToRemove_[i]);
        }
    }

    function _registerAccount(
        address account_,
        uint64 subscriptionEndTime_,
        bytes32 metadata_
    ) internal {
        HelperDataFactoryStorage storage $ = _getHelperDataFactoryStorage();

        require($.registeredAccounts.add(account_), AccountAlreadyRegistered(account_));

        _updateAccountSubscriptionEndTime(account_, subscriptionEndTime_);
        _updateAccountMetadata(account_, metadata_);

        emit AccountRegistered(account_);
    }

    function _updateAccountMetadata(address account_, bytes32 newMetadata_) internal {
        _getHelperDataFactoryStorage().accountsData[account_].metadata = newMetadata_;

        emit AccountMetadataUpdated(account_, newMetadata_);
    }

    function _updateAccountSubscriptionEndTime(address account_, uint64 newEndTime_) internal {
        _getHelperDataFactoryStorage().accountsData[account_].subscriptionEndTime = newEndTime_;

        emit AccountSubscriptionEndTimeUpdated(account_, newEndTime_);
    }

    function _submitHelperDataPart(
        address account_,
        uint256 partIndex_,
        bytes memory data_
    ) internal onlyRegisteredAccount(account_) returns (address partPointer_) {
        HelperDataFactoryStorage storage $ = _getHelperDataFactoryStorage();
        AccountData storage accountData = $.accountsData[account_];

        require(
            !accountData.helperDataParts.contains(partIndex_),
            HelperDataIndexAlreadySet(account_, partIndex_)
        );

        bytes memory submitData_ = abi.encode(account_, partIndex_, data_);

        partPointer_ = SSTORE2.write(submitData_);

        $.registeredAccounts.add(account_);
        accountData.helperDataParts.set(partIndex_, partPointer_);

        emit HelperDataPartSubmitted(account_, partIndex_, partPointer_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _checkHelperDataManager(address manager_) internal view {
        require(isHelperDataManager(manager_), NotAHelperDataManager(manager_));
    }

    function _onlyRegisteredAccount(address account_) internal view {
        require(isAccountRegistered(account_), NotARegisteredAccount(account_));
    }
}
