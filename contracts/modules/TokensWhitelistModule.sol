// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IPriceManager} from "../interfaces/IPriceManager.sol";
import {ITokensWhitelistModule} from "../interfaces/modules/ITokensWhitelistModule.sol";

import {TokensPriceModule} from "./TokensPriceModule.sol";

contract TokensWhitelistModule is ITokensWhitelistModule, TokensPriceModule {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant TOKENS_WHITELIST_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.tokens.whitelist.module.storage");

    struct TokensWhitelistModuleStorage {
        EnumerableSet.AddressSet whitelistedTokens;
    }

    modifier onlyWhitelistedToken(address tokenAddr_) {
        _onlyWhitelistedToken(tokenAddr_);
        _;
    }

    function _getTokensWhitelistModuleStorage()
        private
        pure
        returns (TokensWhitelistModuleStorage storage _twms)
    {
        bytes32 slot_ = TOKENS_WHITELIST_MODULE_STORAGE_SLOT;

        assembly {
            _twms.slot := slot_
        }
    }

    function getWhitelistedTokensCount() external view returns (uint256) {
        return _getTokensWhitelistModuleStorage().whitelistedTokens.length();
    }

    function getWhitelistedTokens() external view returns (address[] memory) {
        return _getTokensWhitelistModuleStorage().whitelistedTokens.values();
    }

    function isTokenWhitelisted(address tokenAddr_) public view returns (bool) {
        return _getTokensWhitelistModuleStorage().whitelistedTokens.contains(tokenAddr_);
    }

    function _addTokensToWhitelist(address[] memory tokensToAdd_) internal {
        TokensWhitelistModuleStorage storage $ = _getTokensWhitelistModuleStorage();

        for (uint256 i = 0; i < tokensToAdd_.length; i++) {
            _onlySupportedToken(tokensToAdd_[i]);

            $.whitelistedTokens.add(tokensToAdd_[i]);
        }

        emit TokensWhitelisted(tokensToAdd_);
    }

    function _removeTokensFromWhitelist(address[] memory tokensToRemove_) internal {
        TokensWhitelistModuleStorage storage $ = _getTokensWhitelistModuleStorage();

        for (uint256 i = 0; i < tokensToRemove_.length; i++) {
            _onlyWhitelistedToken(tokensToRemove_[i]);

            $.whitelistedTokens.remove(tokensToRemove_[i]);
        }

        emit TokensUnwhitelisted(tokensToRemove_);
    }

    function _onlyWhitelistedToken(address tokenAddr_) internal view {
        require(isTokenWhitelisted(tokenAddr_), NotAWhitelistedToken(tokenAddr_));
    }
}
