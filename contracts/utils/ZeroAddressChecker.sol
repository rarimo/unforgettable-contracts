// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract ZeroAddressChecker {
    error ZeroAddr(string fieldName);

    function _checkAddress(address addr_, string memory fieldName_) internal pure virtual {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
