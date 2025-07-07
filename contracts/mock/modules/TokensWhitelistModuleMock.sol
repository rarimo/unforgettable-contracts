// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TokensWhitelistModule} from "../../modules/TokensWhitelistModule.sol";

contract TokensWhitelistModuleMock is TokensWhitelistModule {
    function setPriceManager(address priceManager_) external {
        _setPriceManager(priceManager_);
    }

    function addTokensToWhitelist(address[] memory tokensToAdd_) external {
        _addTokensToWhitelist(tokensToAdd_);
    }

    function removeTokensFromWhitelist(address[] memory tokensToRemove_) external {
        _removeTokensFromWhitelist(tokensToRemove_);
    }
}
