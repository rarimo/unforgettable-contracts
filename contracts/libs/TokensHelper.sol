// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TokensHelper {
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error NotEnoughTokens(address tokenAddr, uint256 requiredAmount_, uint256 availableAmount_);

    function receiveTokens(address tokenAddr_, address from_, uint256 amount_) internal {
        if (isNativeToken(tokenAddr_)) {
            require(msg.value >= amount_, NotEnoughTokens(ETH_ADDR, amount_, msg.value));

            uint256 extraValue_ = msg.value - amount_;
            if (extraValue_ > 0) {
                Address.sendValue(payable(from_), extraValue_);
            }
        } else {
            IERC20(tokenAddr_).safeTransferFrom(from_, address(this), amount_);
        }
    }

    function sendTokens(address tokenAddr_, address to_, uint256 amount_) internal {
        amount_ = Math.min(amount_, getSelfBalance(tokenAddr_));

        _sendTokens(tokenAddr_, to_, amount_);
    }

    function sendTokensStrict(address tokenAddr_, address to_, uint256 amount_) internal {
        uint256 currentBalance_ = getSelfBalance(tokenAddr_);
        require(currentBalance_ >= amount_, NotEnoughTokens(tokenAddr_, amount_, currentBalance_));

        _sendTokens(tokenAddr_, to_, amount_);
    }

    function getSelfBalance(address tokenAddr_) internal view returns (uint256) {
        return getBalance(address(this), tokenAddr_);
    }

    function getBalance(address tokenAddr_, address account_) internal view returns (uint256) {
        if (isNativeToken(tokenAddr_)) {
            return account_.balance;
        } else {
            return IERC20(tokenAddr_).balanceOf(account_);
        }
    }

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
