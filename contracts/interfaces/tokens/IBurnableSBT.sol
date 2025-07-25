// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IBurnableSBT {
    function burn(uint256 tokenId_) external;

    function ownerOf(uint256 tokenId_) external view returns (address);
}
