// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import {AMultiOwnable} from "@solarity/solidity-lib/access/AMultiOwnable.sol";

contract SBTMock is ERC721Upgradeable, AMultiOwnable {
    error TokenDoesNotExist(uint256 tokenId);
    error NotAuthorizedToBurn(address caller, uint256 tokenId);
    error TokenNotTransferable();

    modifier tokenExists(uint256 tokenId_) {
        require(_ownerOf(tokenId_) != address(0), TokenDoesNotExist(tokenId_));
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address[] memory initialOwners_
    ) external initializer {
        __AMultiOwnable_init(initialOwners_);
        __ERC721_init(name_, symbol_);
    }

    function mint(address to_, uint256 tokenId_) external {
        _mint(to_, tokenId_);
    }

    function burn(uint256 tokenId_) external tokenExists(tokenId_) {
        address tokenOwner_ = ownerOf(tokenId_);
        require(
            msg.sender == tokenOwner_ || isOwner(msg.sender),
            NotAuthorizedToBurn(msg.sender, tokenId_)
        );

        _burn(tokenId_);
    }

    function _update(
        address to_,
        uint256 tokenId_,
        address auth_
    ) internal virtual override returns (address) {
        address from_ = _ownerOf(tokenId_);

        if (from_ == address(0)) {
            return super._update(to_, tokenId_, auth_);
        }

        if (to_ == address(0)) {
            return super._update(to_, tokenId_, auth_);
        }

        revert TokenNotTransferable();
    }
}
