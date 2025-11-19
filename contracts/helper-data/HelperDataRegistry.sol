// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title HelperDataRegistry
 * @notice Registry for storing accounts helper data
 */
contract HelperDataRegistry is EIP712Upgradeable {
    /**
     * @notice Data structure storing helper data for an account.
     * @param faceVersion Version of the facial data.
     * @param objectVersion Version of the object data.
     * @param helperDataVersion Version of the helper data.
     * @param helperData Encoded bytes representing the helper data.
     */
    struct HelperData {
        uint64 faceVersion;
        uint96 objectVersion;
        uint96 helperDataVersion;
        bytes helperData;
    }

    struct HelperDataRegistryStorage {
        mapping(address => HelperData) accountsToHelperData;
    }

    bytes32 public constant HELPERDATA_REGISTRY_STORAGE_SLOT =
        keccak256("unforgettable.contract.helper.data.registry.storage");

    bytes32 private constant HELPERDATA_TYPEHASH =
        keccak256(
            "HelperData(uint256 faceVersion,uint256 objectVersion,uint256 helperDataVersion,bytes helperData)"
        );

    /**
     * @notice Thrown when trying to set helper data for an account that already has it.
     * @param signer The account address that already has helper data set.
     */
    error HelperDataAlreadySet(address signer);

    /**
     * @notice Emitted when the helper data is set for an account.
     * @param account The account address for which helper data was set.
     */
    event HelperDataSet(address indexed account);

    function initialize() external initializer {
        __EIP712_init("HelperDataRegistry", "1");
    }

    /**
     * @notice A function to set helper data for an account.
     * @dev Reverts if helper data is already set for the signer.
     * @param helperData_ The helper data struct to set.
     * @param signature_ The EIP-712 signature of the helper data signed by the account to set the data for.
     */
    function setHelperData(HelperData calldata helperData_, bytes calldata signature_) external {
        bytes32 digest_ = hashHelperDataStruct(helperData_);

        address signer_ = ECDSA.recover(digest_, signature_);

        require(!isHelperDataSet(signer_), HelperDataAlreadySet(signer_));

        _getHelperDataRegistryStorage().accountsToHelperData[signer_] = helperData_;

        emit HelperDataSet(signer_);
    }

    /**
     * @notice A function to retrieve the helper data for the provided account.
     * @param account_ The account address to query.
     * @return The `HelperData` struct associated with the account.
     */
    function getHelperData(address account_) external view returns (HelperData memory) {
        return _getHelperDataRegistryStorage().accountsToHelperData[account_];
    }

    /**
     * @notice A function to compute the EIP-712 hash for a given `HelperData` struct.
     * @param helperData_ The helper data to hash.
     * @return The EIP-712 typed hash of the helper data struct.
     */
    function hashHelperDataStruct(HelperData calldata helperData_) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        HELPERDATA_TYPEHASH,
                        helperData_.faceVersion,
                        helperData_.objectVersion,
                        helperData_.helperDataVersion,
                        keccak256(helperData_.helperData)
                    )
                )
            );
    }

    /**
     * @notice A function to check whether helper data is already set for the provided account.
     * @param account_ The account address to check.
     * @return `true` if helper data exists for the account, `false` otherwise.
     */
    function isHelperDataSet(address account_) public view returns (bool) {
        return
            _getHelperDataRegistryStorage().accountsToHelperData[account_].helperDataVersion != 0;
    }

    function _getHelperDataRegistryStorage()
        private
        pure
        returns (HelperDataRegistryStorage storage _hdrs)
    {
        bytes32 slot_ = HELPERDATA_REGISTRY_STORAGE_SLOT;

        assembly {
            _hdrs.slot := slot_
        }
    }
}
