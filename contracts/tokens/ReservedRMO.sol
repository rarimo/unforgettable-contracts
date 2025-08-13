// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IReservedRMO} from "../interfaces/tokens/IReservedRMO.sol";
import {IVaultFactory} from "../interfaces/vaults/IVaultFactory.sol";

contract ReservedRMO is
    IReservedRMO,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant RESERVED_RMO_STORAGE_SLOT =
        keccak256("unforgettable.contract.token.reserved.rmo.storage");

    struct ReservedRMOStorage {
        IVaultFactory vaultFactory;
        IERC20 rmoToken;
        uint256 reservedTokensPerAddress;
        mapping(address => uint256) mintedAmounts;
    }

    modifier onlyRMOToken() {
        _onlyRMOToken();
        _;
    }

    function _getReservedRMOStorage() private pure returns (ReservedRMOStorage storage _rrmo) {
        bytes32 slot_ = RESERVED_RMO_STORAGE_SLOT;

        assembly {
            _rrmo.slot := slot_
        }
    }

    function initialize(
        address vaultFactory_,
        uint256 reservedTokensPerAddress_
    ) external initializer {
        __ERC20_init("Reserved RMO", "rRMO");
        __Ownable_init(msg.sender);

        _getReservedRMOStorage().vaultFactory = IVaultFactory(vaultFactory_);

        _setReservedTokensPerAddress(reservedTokensPerAddress_);

        _pause();
    }

    /// @inheritdoc IReservedRMO
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc IReservedRMO
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc IReservedRMO
    function setRMOToken(address rmoToken_) external onlyOwner {
        ReservedRMOStorage storage $ = _getReservedRMOStorage();

        require(address($.rmoToken) == address(0), RMOTokenAlreadySet());

        $.rmoToken = IERC20(rmoToken_);

        emit RMOTokenSet(rmoToken_);
    }

    /// @inheritdoc IReservedRMO
    function setReservedTokensPerAddress(uint256 newReservedTokensAmount_) external onlyOwner {
        _setReservedTokensPerAddress(newReservedTokensAmount_);
    }

    /// @inheritdoc IReservedRMO
    function mintReservedTokens(address vaultAddress_) external {
        ReservedRMOStorage storage $ = _getReservedRMOStorage();

        require($.vaultFactory.isVault(vaultAddress_), NotAVault(vaultAddress_));
        require(
            $.mintedAmounts[vaultAddress_] == 0,
            TokensAlreadyMintedForThisVault(vaultAddress_)
        );

        uint256 reservedTokensPerAddress_ = $.reservedTokensPerAddress;

        $.mintedAmounts[vaultAddress_] = reservedTokensPerAddress_;

        _mint(vaultAddress_, reservedTokensPerAddress_);
    }

    /// @inheritdoc IReservedRMO
    function burnReservedTokens(address account_, uint256 amount_) external onlyRMOToken {
        _burn(account_, amount_);
    }

    /// @inheritdoc IReservedRMO
    function getRMOToken() external view returns (address) {
        return address(_getReservedRMOStorage().rmoToken);
    }

    /// @inheritdoc IReservedRMO
    function getVaultFactory() external view returns (address) {
        return address(_getReservedRMOStorage().vaultFactory);
    }

    /// @inheritdoc IReservedRMO
    function getReservedTokensPerAddress() external view returns (uint256) {
        return _getReservedRMOStorage().reservedTokensPerAddress;
    }

    /// @inheritdoc IReservedRMO
    function getMintedAmount(address vaultAddress_) external view returns (uint256) {
        return _getReservedRMOStorage().mintedAmounts[vaultAddress_];
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function _setReservedTokensPerAddress(uint256 newReservedTokensAmount_) internal {
        require(newReservedTokensAmount_ > 0, ZeroReservedTokensAmountPerAddress());

        _getReservedRMOStorage().reservedTokensPerAddress = newReservedTokensAmount_;

        emit ReservedTokensPerAddressUpdated(newReservedTokensAmount_);
    }

    function _update(address from_, address to_, uint256 value_) internal override {
        if (from_ != address(0) && to_ != address(0)) {
            _requireNotPaused();
        }

        super._update(from_, to_, value_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _onlyRMOToken() internal view {
        require(msg.sender == address(_getReservedRMOStorage().rmoToken), NotRMOToken(msg.sender));
    }
}
