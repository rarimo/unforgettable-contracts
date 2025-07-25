// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VaultMock {
    address public owner;

    constructor(address owner_) {
        owner = owner_;
    }
}
