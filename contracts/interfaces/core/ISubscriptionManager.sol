// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokensPaymentModule} from "./subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "./subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "./subscription/ISignatureSubscriptionModule.sol";

interface ISubscriptionManager is
    ITokensPaymentModule,
    ISBTPaymentModule,
    ISignatureSubscriptionModule
{
    error NotARecoveryManager(address sender);
    error NotASubscriptionCreator(address sender);
    error SubscriptionAlreadyCreated(address account);

    event RecoveryManagerUpdated(address recoveryManager);
    event SubscriptionCreated(address indexed account, uint256 startTime);

    function pause() external;

    function unpause() external;

    function createSubscription(address account_) external;

    function implementation() external view returns (address);

    function getSubscriptionCreators() external view returns (address[] memory);

    function isSubscriptionCreator(address account_) external returns (bool);
}
