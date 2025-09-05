// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionMessanger} from "./ISubscriptionMessanger.sol";

interface ISubscriptionsSynchronizer is ISubscriptionMessanger {
    struct SubscriptionsSynchronizerInitData {
        address wormholeRelayer;
        address[] subscriptionManagers;
        Destination[] destinations;
    }

    struct Destination {
        uint16 chainId;
        address targetAddress;
    }

    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionManagerAdded(address indexed subscriptionManager);
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    event DestinationAdded(uint16 indexed chainId, address indexed targetAddress);
    event DestinationRemoved(uint16 indexed chainId);

    error NotSubscriptionManager();
    error InsufficientFundsForCrossChainDelivery();
    error ChainNotSupported(uint16 chainId);
    error InvalidChainId(uint16 chainId);
    error DestinationAlreadyExists(uint16 chainId, address targetAddress);

    function sync(uint16 targetChain_) external payable;

    function saveSubscriptionData(
        address account_,
        uint64 startTime_,
        uint64 endTime_,
        bool isNewSubscription_
    ) external;

    function addSubscriptionManager(address subscriptionManager_) external;

    function removeSubscriptionManager(address subscriptionManager_) external;

    function addDestination(Destination calldata destination_) external;

    function removeDestination(uint16 chainId_) external;

    function getSubscriptionsSMTRoot() external view returns (bytes32 smtRoot_);

    function getSubscriptionsSMTProof(
        address subscriptionManager_,
        address account_
    ) external view returns (bytes32[] memory proof_);

    function isChainSupported(uint16 chainId_) external view returns (bool);
}
