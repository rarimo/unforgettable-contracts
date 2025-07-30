// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {BaseAccount} from "@account-abstraction/contracts/core/BaseAccount.sol";
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@account-abstraction/contracts/core/Helpers.sol";

/**
 * Simple7702Account.sol
 * A minimal account to be used with EIP-7702 (for batching) and ERC-4337 (for gas sponsoring)
 */
contract Simple7702Account is
    BaseAccount,
    IERC165,
    IERC1271,
    ERC1155Holder,
    ERC721Holder,
    UUPSUpgradeable,
    Initializable
{
    error InvalidExecutor(address account);

    address public trustedExecutor;

    function initialize(address trustedExecutor_) public virtual initializer {
        trustedExecutor = trustedExecutor_;
    }

    function entryPoint() public pure override returns (IEntryPoint) {
        return IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
    }

    /**
     * Make this account callable through ERC-4337 EntryPoint.
     * The UserOperation should be signed by this account's private key.
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        return
            _checkSignature(userOpHash, userOp.signature)
                ? SIG_VALIDATION_SUCCESS
                : SIG_VALIDATION_FAILED;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) public view returns (bytes4 magicValue) {
        return
            _checkSignature(hash, signature) ? this.isValidSignature.selector : bytes4(0xffffffff);
    }

    function _checkSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        address recovered_ = ECDSA.recover(hash, signature);

        return recovered_ == address(this) || recovered_ == trustedExecutor;
    }

    function _requireForExecute() internal view virtual override {
        require(
            msg.sender == address(this) ||
                msg.sender == address(entryPoint()) ||
                msg.sender == trustedExecutor,
            InvalidExecutor(msg.sender)
        );
    }

    function supportsInterface(
        bytes4 id
    ) public pure override(ERC1155Holder, IERC165) returns (bool) {
        return
            id == type(IERC165).interfaceId ||
            id == type(IAccount).interfaceId ||
            id == type(IERC1271).interfaceId ||
            id == type(IERC1155Receiver).interfaceId ||
            id == type(IERC721Receiver).interfaceId;
    }

    // accept incoming calls (with or without value), to mimic an EOA.
    fallback() external payable {}

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation) internal override {}
}
