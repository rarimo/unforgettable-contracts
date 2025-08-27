// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICreateX {
    function deployCreate3(
        bytes32 salt_,
        bytes memory initCode_
    ) external payable returns (address newContract_);

    function computeCreate3Address(bytes32 salt_) external view returns (address computedAddress_);
}
