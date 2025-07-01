// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPriceManager} from "../IPriceManager.sol";

interface ITokensPriceModule {
    error InvalidPriceManagerAddress();
    error UnsupportedToken(address tokenAddr);

    event PriceManagerUpdated(address newPriceManagerAddr);

    function tokensPriceManager() external view returns (IPriceManager);
}
