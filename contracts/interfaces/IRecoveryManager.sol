// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IRecoveryProvider} from "./IRecoveryProvider.sol";
import {IStrategiesModule} from "./modules/IStrategiesModule.sol";
import {ISubscriptionModule} from "./modules/ISubscriptionModule.sol";
import {ITokensPriceModule} from "./modules/ITokensPriceModule.sol";
import {ITokensWhitelistModule} from "./modules/ITokensWhitelistModule.sol";

interface IRecoveryManager is
    IRecoveryProvider,
    IStrategiesModule,
    ISubscriptionModule,
    ITokensWhitelistModule
{
    struct NewSubscriptionData {
        address tokenAddr;
        uint256 subscriptionDuration;
        uint256 recoverySecurityPercentage;
        RecoveryMethod[] recoveryMethods;
    }

    // struct AccountRecoveryData {
    //     uint256 subscriptionId;
    //     uint256[] recoveryMethodIds;
    //     bytes[] proofs;
    // }

    struct AccountRecoveryData {
        uint256 recoverySecurityPercentage;
        RecoveryMethod[] recoveryMethods;
    }

    struct SubscriptionPeriodUpdateEntry {
        uint256 duration;
        uint256 strategiesCostFactor;
    }

    struct NewStrategyInfo {
        uint256 baseRecoveryCostInUsd;
        address strategy;
    }
}
