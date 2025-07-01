// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPriceManager} from "../IPriceManager.sol";

interface ITokensWhitelistModule {
    error NotAWhitelistedToken(address tokenAddr);

    event TokensWhitelisted(address[] newWhitelistedTokens);
    event TokensUnwhitelisted(address[] removedTokens);

    function getWhitelistedTokensCount() external view returns (uint256);

    function getWhitelistedTokens() external view returns (address[] memory);

    function isTokenWhitelisted(address tokenAddr_) external view returns (bool);
}
