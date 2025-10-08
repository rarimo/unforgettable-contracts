// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokensHelper
 * @notice Library for handling ERC-20 and native ETH transfers.
 */
library TokensHelper {
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @notice Thrown when insufficient tokens amount is provided.
     * @param tokenAddr The token address (`ETH_ADDR` for native ETH).
     * @param requiredAmount The required amount to perform the operation.
     * @param availableAmount The available amount.
     */
    error NotEnoughTokens(address tokenAddr, uint256 requiredAmount, uint256 availableAmount);

    /**
     * @notice A function to receive tokens from the provided account.
     * @dev If more than `amount_` was sent in ETH, extra ETH is returned to the `from` address.
     * @param tokenAddr_ The token address (`ETH_ADDR` for native ETH).
     * @param from_ The sender address.
     * @param amount_ The amount to receive.
     */
    function receiveTokens(address tokenAddr_, address from_, uint256 amount_) internal {
        if (isNativeToken(tokenAddr_)) {
            require(msg.value >= amount_, NotEnoughTokens(ETH_ADDR, amount_, msg.value));

            uint256 extraValue_ = msg.value - amount_;
            if (extraValue_ > 0) {
                Address.sendValue(payable(from_), extraValue_);
            }
        } else {
            if (amount_ > 0) {
                IERC20(tokenAddr_).safeTransferFrom(from_, address(this), amount_);
            }
        }
    }

    /**
     * @notice A function to send tokens to the provided address.
     * @dev If `amount_` exceeds the balance, the available balance is sent.
     * @param tokenAddr_ The token address (`ETH_ADDR` for native ETH).
     * @param to_ The recipient address.
     * @param amount_ The requested amount to send.
     * @return sentAmount_ The actual amount sent (<= requested).
     */
    function sendTokens(
        address tokenAddr_,
        address to_,
        uint256 amount_
    ) internal returns (uint256 sentAmount_) {
        sentAmount_ = Math.min(amount_, getSelfBalance(tokenAddr_));

        _sendTokens(tokenAddr_, to_, sentAmount_);
    }

    /**
     * @notice A function to retrieve the balance of this contract for the provided token.
     * @param tokenAddr_ The token address (`ETH_ADDR` for native ETH).
     * @return The balance held by this contract.
     */
    function getSelfBalance(address tokenAddr_) internal view returns (uint256) {
        return getBalance(tokenAddr_, address(this));
    }

    /**
     * @notice A function to retrieve the balance of the given account for the provided token.
     * @param tokenAddr_ The token address (`ETH_ADDR` for native ETH).
     * @param account_ The account address to query.
     * @return The balance held by the account.
     */
    function getBalance(address tokenAddr_, address account_) internal view returns (uint256) {
        if (isNativeToken(tokenAddr_)) {
            return account_.balance;
        } else {
            return IERC20(tokenAddr_).balanceOf(account_);
        }
    }

    /**
     * @notice A function to check whether the provided token address represents native ETH.
     * @param tokenAddr_ The token address to check.
     * @return `true` if `tokenAddr_` equals `ETH_ADDR`, `false` otherwise.
     */
    function isNativeToken(address tokenAddr_) internal pure returns (bool) {
        return ETH_ADDR == tokenAddr_;
    }

    function _sendTokens(address tokenAddr_, address to_, uint256 amount_) private {
        if (isNativeToken(tokenAddr_)) {
            Address.sendValue(payable(to_), amount_);
        } else {
            IERC20(tokenAddr_).safeTransfer(to_, amount_);
        }
    }
}
