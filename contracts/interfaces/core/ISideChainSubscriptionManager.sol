// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./subscription/IBaseSubscriptionModule.sol";

interface ISideChainSubscriptionManager is IBaseSubscriptionModule {
    struct SideChainSubscriptionManagerInitData {
        address subscriptionsStateReceiver;
        address sourceSubscriptionManager;
    }

    event SubscriptionSynced(address indexed account, uint64 startTime, uint64 endTime);
    event SubscriptionsStateReceiverUpdated(address indexed subscriptionsStateReceiver);
    event SourceSubscriptionManagerUpdated(address indexed sourceSubscriptionManager);

    error UknownRoot(bytes32 root);
    error InvalidSMTKey();
    error InvalidSMTValue();
    error InvalidSMTProof();
}
