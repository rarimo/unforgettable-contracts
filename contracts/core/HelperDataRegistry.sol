// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract HelperDataRegistry is EIP712Upgradeable {
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

    error HelperDataAlreadySet(address signer);

    event HelperDataSet(address indexed account);

    function initialize() external initializer {
        __EIP712_init("HelperDataRegistry", "1");
    }

    function setHelperData(HelperData calldata helperData_, bytes calldata signature_) external {
        bytes32 digest_ = hashHelperDataStruct(helperData_);

        address signer_ = ECDSA.recover(digest_, signature_);

        require(!isHelperDataSet(signer_), HelperDataAlreadySet(signer_));

        _getRecoveryManagerStorage().accountsToHelperData[signer_] = helperData_;

        emit HelperDataSet(signer_);
    }

    function getHelperData(address account_) external view returns (HelperData memory) {
        return _getRecoveryManagerStorage().accountsToHelperData[account_];
    }

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

    function isHelperDataSet(address account_) public view returns (bool) {
        return _getRecoveryManagerStorage().accountsToHelperData[account_].helperDataVersion != 0;
    }

    function _getRecoveryManagerStorage()
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
