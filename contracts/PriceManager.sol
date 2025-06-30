// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IPriceManager} from "./interfaces/IPriceManager.sol";

contract PriceManager is IPriceManager, OwnableUpgradeable {
    address public usdTokenAddr;

    function initialize(address usdTokenAddr_) external initializer {
        require(usdTokenAddr_ != address(0));

        __Ownable_init(msg.sender);

        usdTokenAddr = usdTokenAddr_;
    }

    function isTokenSupported(address tokenAddr_) external view returns (bool) {
        return usdTokenAddr == tokenAddr_;
    }

    function getAmountInUsd(
        address tokenAddr_,
        uint256 tokensAmount_
    ) external view returns (uint256) {
        if (tokenAddr_ == usdTokenAddr) {
            return tokensAmount_;
        }

        return 0;
    }

    function getAmountFromUsd(
        address tokenAddr_,
        uint256 usdAmount_
    ) external view returns (uint256) {
        if (tokenAddr_ == usdTokenAddr) {
            return usdAmount_;
        }

        return 0;
    }
}
