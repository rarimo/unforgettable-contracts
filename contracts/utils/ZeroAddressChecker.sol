// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ZeroAddressChecker
 * @notice A utility contract to check for zero addresses.
 */
contract ZeroAddressChecker {
    /// @notice Error thrown when a zero address is encountered.
    error ZeroAddr(string fieldName);

    function _checkAddress(address addr_, string memory fieldName_) internal pure virtual {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
