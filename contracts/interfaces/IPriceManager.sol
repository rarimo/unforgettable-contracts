// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPriceManager {
    function usdTokenAddr() external view returns (address);

    function isTokenSupported(address tokenAddr_) external view returns (bool);

    function getAmountInUsd(
        address tokenAddr_,
        uint256 tokensAmount_
    ) external view returns (uint256);

    function getAmountFromUsd(
        address tokenAddr_,
        uint256 usdAmount_
    ) external view returns (uint256);
}
