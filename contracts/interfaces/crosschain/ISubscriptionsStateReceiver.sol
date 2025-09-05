// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeReceiver} from "@wormhole/interfaces/IWormholeRelayer.sol";
import {ISubscriptionMessanger} from "./ISubscriptionMessanger.sol";

interface ISubscriptionsStateReceiver is IWormholeReceiver, ISubscriptionMessanger {
    struct SubscriptionsStateReceiverInitData {
        address wormholeRelayer;
        address subscriptionsSynchronizer;
        uint16 sourceChainId;
    }

    event MessageReceived(bytes message);
    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionsSynchronizerUpdated(address indexed synchronizer);
    event SourceChainIdUpdated(uint16 indexed chainId);

    error NotWormholeRelayer(address);
    error InvalidSourceChainId();
    error InvalidSourceAddress();
    error OutdatedSyncMessage();

    function updateWormholeRelayer(address wormholeRelayer_) external;

    function updateSubscriptionsSynchronizer(address subscriptionStateSynchronizer_) external;

    function updateSourceChainId(uint16 sourceChainId_) external;

    function rootInHistory(bytes32 smtRoot_) external view returns (bool);
}
