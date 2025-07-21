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

    event HelperDataSet(address indexed account, HelperData helperData);

    function initialize() external initializer {
        __EIP712_init("HelperDataRegistry", "1");
    }

    function setHelperData(HelperData calldata helperData_, bytes calldata signature_) external {
        bytes32 digest_ = _hashTypedDataV4(getHelperDataStructHash(helperData_));

        address signer_ = ECDSA.recover(digest_, signature_);

        HelperDataRegistryStorage storage $ = _getRecoveryManagerStorage();

        require(
            $.accountsToHelperData[signer_].helperDataVersion == 0,
            HelperDataAlreadySet(signer_)
        );

        $.accountsToHelperData[signer_] = helperData_;

        emit HelperDataSet(signer_, helperData_);
    }

    function getHelperData(address account_) external view returns (HelperData memory) {
        return _getRecoveryManagerStorage().accountsToHelperData[account_];
    }

    function getHelperDataStructHash(
        HelperData calldata helperData_
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    HELPERDATA_TYPEHASH,
                    helperData_.faceVersion,
                    helperData_.objectVersion,
                    helperData_.helperDataVersion,
                    keccak256(helperData_.helperData)
                )
            );
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
