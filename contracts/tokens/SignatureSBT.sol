// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {ASBT} from "@solarity/solidity-lib/tokens/ASBT.sol";
import {AMultiOwnable} from "@solarity/solidity-lib/access/AMultiOwnable.sol";

import {ISignatureSBT} from "../interfaces/tokens/ISignatureSBT.sol";

contract SignatureSBT is ISignatureSBT, ASBT, AMultiOwnable, UUPSUpgradeable, EIP712Upgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MINT_SBT_TYPEHASH =
        keccak256("MintSBT(address recipient,uint256 tokenId,bytes32 tokenURIHash)");

    bytes32 public constant SIGNATURE_SBT_STORAGE_SLOT =
        keccak256("unforgettable.contract.token.signature.sbt.storage");

    struct SignatureSBTStorage {
        EnumerableSet.AddressSet signers;
    }

    function _getSignatureSBTStorage() private pure returns (SignatureSBTStorage storage _ssbts) {
        bytes32 slot_ = SIGNATURE_SBT_STORAGE_SLOT;

        assembly {
            _ssbts.slot := slot_
        }
    }

    function initialize(string memory name_, string memory symbol_) external initializer {
        __ASBT_init(name_, symbol_);
        __EIP712_init(name_, "v1.0.0");
        __AMultiOwnable_init();
    }

    /// @inheritdoc ISignatureSBT
    function addSigners(address[] calldata signersToAdd_) external onlyOwner {
        SignatureSBTStorage storage $ = _getSignatureSBTStorage();

        for (uint256 i = 0; i < signersToAdd_.length; i++) {
            require($.signers.add(signersToAdd_[i]), SignerAlreadyAdded(signersToAdd_[i]));

            emit SignerAdded(signersToAdd_[i]);
        }
    }

    /// @inheritdoc ISignatureSBT
    function removeSigners(address[] calldata signersToRemove_) external onlyOwner {
        SignatureSBTStorage storage $ = _getSignatureSBTStorage();

        for (uint256 i = 0; i < signersToRemove_.length; i++) {
            require($.signers.remove(signersToRemove_[i]), NotASigner(signersToRemove_[i]));

            emit SignerRemoved(signersToRemove_[i]);
        }
    }

    /// @inheritdoc ISignatureSBT
    function mintSBT(
        address recipient_,
        uint256 tokenId_,
        string calldata tokenURI_,
        bytes calldata signature_
    ) external {
        bytes32 mintSBTHash_ = hashMintSBT(recipient_, tokenId_, tokenURI_);

        _checkSignature(mintSBTHash_, signature_);

        _mint(recipient_, tokenId_);
        _setTokenURI(tokenId_, tokenURI_);

        emit SBTMinted(recipient_, tokenId_, tokenURI_);
    }

    /// @inheritdoc ISignatureSBT
    function getSigners() external view returns (address[] memory) {
        return _getSignatureSBTStorage().signers.values();
    }

    /// @inheritdoc ISignatureSBT
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @inheritdoc ISignatureSBT
    function isSigner(address signer_) public view returns (bool) {
        return _getSignatureSBTStorage().signers.contains(signer_);
    }

    /// @inheritdoc ISignatureSBT
    function hashMintSBT(
        address recipient_,
        uint256 tokenId_,
        string calldata tokenURI
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        MINT_SBT_TYPEHASH,
                        recipient_,
                        tokenId_,
                        keccak256(abi.encode(tokenURI))
                    )
                )
            );
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _checkSignature(bytes32 hash_, bytes memory signature_) internal view {
        (address recovered_, ECDSA.RecoverError err_, ) = ECDSA.tryRecover(hash_, signature_);

        require(err_ == ECDSA.RecoverError.NoError, InvalidSignature());
        require(isSigner(recovered_), NotASigner(recovered_));
    }
}
