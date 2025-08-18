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
    error NotASubscriptionActivator(address sender);
    error SubscriptionAlreadyActivated(address account);

    event RecoveryManagerUpdated(address recoveryManager);
    event SubscriptionActivated(address indexed account, uint256 startTime);

    function pause() external;

    function unpause() external;

    function activateSubscription(address account_) external;

    function getRecoveryManager() external view returns (address);

    function isSubscriptionActivator(address account_) external returns (bool);
}
