// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBurnableSBT {
    /**
     * @notice Burns a token.
     * @dev Removes the token permanently from circulation.
     * @dev The caller must own `tokenId` or be an approved operator.
     * @param tokenId_ The ID of the token to burn.
     */
    function burn(uint256 tokenId_) external;

    /**
     * @notice Returns the owner of the `tokenId` token.
     * @param tokenId_ The ID of the token to query.
     * @return The `tokenId` token owner address.
     */
    function ownerOf(uint256 tokenId_) external view returns (address);
}
