// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract HelperDataRegistry is EIP712Upgradeable {
    struct HelperData {
        uint256 faceVersion;
        uint256 objectVersion;
        uint256 helperDataVersion;
        bytes helperData;
    }

    error HelperDataAlreadySet(address signer);

    bytes32 private constant HELPERDATA_TYPEHASH =
        keccak256(
            "HelperData(uint256 faceVersion,uint256 objectVersion,uint256 helperDataVersion,bytes helperData)"
        );

    mapping(address => HelperData) private _accountsToHelperData;

    function initialize() external initializer {
        __EIP712_init("HelperDataRegistry", "1");
    }

    function setHelperData(HelperData calldata helperData_, bytes calldata signature_) external {
        bytes32 structHash_ = keccak256(
            abi.encode(
                HELPERDATA_TYPEHASH,
                helperData_.faceVersion,
                helperData_.objectVersion,
                helperData_.helperDataVersion,
                keccak256(helperData_.helperData)
            )
        );

        bytes32 digest_ = _hashTypedDataV4(structHash_);

        address signer_ = ECDSA.recover(digest_, signature_);

        require(
            _accountsToHelperData[signer_].helperDataVersion == 0,
            HelperDataAlreadySet(signer_)
        );

        _accountsToHelperData[signer_] = helperData_;
    }

    function getHelperData(address account_) external view returns (HelperData memory) {
        return _accountsToHelperData[account_];
    }
}
