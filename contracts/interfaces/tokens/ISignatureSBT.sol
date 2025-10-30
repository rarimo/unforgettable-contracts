// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISBT} from "@solarity/solidity-lib/interfaces/tokens/ISBT.sol";
/**
 * @title ISignatureSBT
 * @notice Interface for a signature-authorized Soulbound Token (SBT).
 *         Authorized signers can produce off-chain signatures that allow
 *         minting of SBTs on-chain via `mintSBT`.
 */
interface ISignatureSBT is ISBT {
    /**
     * @notice Thrown when attempting to add a signer that already exists.
     * @param signer The address that was already added as a signer.
     */
    error SignerAlreadyAdded(address signer);

    /**
     * @notice Thrown when an operation expects a signer but the address is not one.
     * @param signer The address that is not registered as a signer.
     */
    error NotASigner(address signer);

    /**
     * @notice Thrown when a provided signature fails verification.
     */
    error InvalidSignature();

    /**
     * @notice Emitted when a new signer is added to the authorized signer list.
     * @param signer The address that was added as a signer.
     */
    event SignerAdded(address indexed signer);

    /**
     * @notice Emitted when an existing signer is removed.
     * @param signer The address that was removed from signers.
     */
    event SignerRemoved(address indexed signer);

    /**
     * @notice Emitted after successful minting of an SBT via a verified signature.
     * @param recipient The address that received the minted token.
     * @param tokenId The identifier of the minted token.
     * @param tokenURI The metadata URI assigned to the minted token.
     */
    event SBTMinted(address indexed recipient, uint256 tokenId, string tokenURI);

    /**
     * @notice Adds one or more addresses as authorized signers.
     * @param signersToAdd_ Array of addresses to register as signers.
     */
    function addSigners(address[] calldata signersToAdd_) external;

    /**
     * @notice Removes one or more addresses from the authorized signer list.
     * @param signersToRemove_ Array of addresses to remove from signers.
     */
    function removeSigners(address[] calldata signersToRemove_) external;

    /**
     * @notice Mints an SBT to `recipient_` when a valid off-chain signature is provided.
     * @param recipient_ Address that will receive the minted SBT.
     * @param tokenId_ Identifier of the token to mint.
     * @param tokenURI_ Metadata URI to associate with the minted token.
     * @param signature_ Off-chain signature produced by an authorized signer.
     */
    function mintSBT(
        address recipient_,
        uint256 tokenId_,
        string calldata tokenURI_,
        bytes calldata signature_
    ) external;

    /**
     * @notice Returns the list of currently authorized signer addresses.
     * @return An array of signer addresses.
     */
    function getSigners() external view returns (address[] memory);

    /**
     * @notice Returns the implementation address.
     * @return The implementation contract address.
     */
    function implementation() external view returns (address);

    /**
     * @notice Checks whether `signer_` is an authorized signer.
     * @param signer_ Address to check for signer status.
     * @return True if `signer_` is a registered signer, otherwise false.
     */
    function isSigner(address signer_) external view returns (bool);

    /**
     * @notice Computes the hash that must be signed off-chain to authorize minting.
     * @param recipient_ Recipient address included in the signed payload.
     * @param tokenId_ Token identifier included in the signed payload.
     * @param tokenURI Token URI included in the signed payload.
     * @return The keccak256 hash of the minting payload used for signature verification.
     */
    function hashMintSBT(
        address recipient_,
        uint256 tokenId_,
        string calldata tokenURI
    ) external view returns (bytes32);
}
