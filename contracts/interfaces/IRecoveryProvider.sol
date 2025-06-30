// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IRecoveryProvider {
    event AccountSubscribed(address indexed account);
    event AccountUnsubscribed(address indexed account);

    function subscribe(bytes memory recoveryData_) external;
    function unsubscribe() external;

    function recover(address newOwner_, bytes memory proof_) external;

    function getRecoveryData(address account_) external view returns (bytes memory);
}
