// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IPriceManager} from "../interfaces/IPriceManager.sol";
import {ITokensPriceModule} from "../interfaces/modules/ITokensPriceModule.sol";

contract TokensPriceModule is ITokensPriceModule {
    bytes32 public constant TOKENS_PRICE_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.tokens.price.module.storage");

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct TokensPriceModuleStorage {
        IPriceManager priceManager;
    }

    function _getTokensPriceModuleStorage()
        private
        pure
        returns (TokensPriceModuleStorage storage _tpms)
    {
        bytes32 slot_ = TOKENS_PRICE_MODULE_STORAGE_SLOT;

        assembly {
            _tpms.slot := slot_
        }
    }

    function tokensPriceManager() public view returns (IPriceManager) {
        return _getTokensPriceModuleStorage().priceManager;
    }

    function getAmountInUsd(
        address tokenAddr_,
        uint256 tokensAmount_
    ) public view returns (uint256) {
        _onlySupportedToken(tokenAddr_);

        return tokensPriceManager().getAmountInUsd(tokenAddr_, tokensAmount_);
    }

    function getAmountFromUsd(
        address tokenAddr_,
        uint256 usdAmount_
    ) public view returns (uint256) {
        _onlySupportedToken(tokenAddr_);

        return tokensPriceManager().getAmountFromUsd(tokenAddr_, usdAmount_);
    }

    function isTokenSupported(address tokenAddr_) public view returns (bool) {
        return _getTokensPriceModuleStorage().priceManager.isTokenSupported(tokenAddr_);
    }

    function isNativeToken(address tokenAddr_) public pure returns (bool) {
        return tokenAddr_ == ETH_ADDR;
    }

    function _setPriceManager(address newPriceManager_) internal {
        require(newPriceManager_ != address(0), InvalidPriceManagerAddress());

        _getTokensPriceModuleStorage().priceManager = IPriceManager(newPriceManager_);

        emit PriceManagerUpdated(newPriceManager_);
    }

    function _onlySupportedToken(address tokenAddr_) internal view {
        require(isTokenSupported(tokenAddr_), UnsupportedToken(tokenAddr_));
    }
}
