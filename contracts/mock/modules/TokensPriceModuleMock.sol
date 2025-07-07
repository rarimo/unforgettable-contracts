// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TokensPriceModule} from "../../modules/TokensPriceModule.sol";

contract TokensPriceModuleMock is TokensPriceModule {
    function setPriceManager(address priceManager_) external {
        _setPriceManager(priceManager_);
    }
}
