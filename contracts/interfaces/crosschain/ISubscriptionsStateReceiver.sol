// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeReceiver} from "@wormhole/interfaces/IWormholeRelayer.sol";
import {ISubscriptionMessanger} from "./ISubscriptionMessanger.sol";

/**
 * @title ISubscriptionsStateReceiver
 * @notice Interface for receiving and processing subscription state messages via Wormhole.
 */
interface ISubscriptionsStateReceiver is IWormholeReceiver, ISubscriptionMessanger {
    /**
     * @notice Initialization data for the subscriptions state receiver.
     * @param wormholeRelayer The address of the Wormhole relayer.
     * @param subscriptionsSynchronizer The address of the subscriptions synchronizer.
     * @param sourceChainId The ID of the source chain.
     */
    struct SubscriptionsStateReceiverInitData {
        address wormholeRelayer;
        address subscriptionsSynchronizer;
        uint16 sourceChainId;
    }

    /**
     * @notice Event emitted when a message is received.
     * @param message The received message.
     */
    event MessageReceived(bytes message);
    /**
     * @notice Event emitted when the Wormhole relayer is updated.
     * @param relayer The address of the updated Wormhole relayer.
     */
    event WormholeRelayerUpdated(address indexed relayer);
    /**
     * @notice Event emitted when the subscriptions synchronizer is updated.
     * @param synchronizer The address of the updated subscriptions synchronizer.
     */
    event SubscriptionsSynchronizerUpdated(address indexed synchronizer);
    /**
     * @notice Event emitted when the source chain ID is updated.
     * @param chainId The updated source chain ID.
     */
    event SourceChainIdUpdated(uint16 indexed chainId);

    /**
     * @notice Thrown when the caller is not the Wormhole relayer.
     * @param caller The address of the caller.
     */
    error NotWormholeRelayer(address caller);
    /**
     * @notice Thrown when an invalid source chain ID is encountered.
     */
    error InvalidSourceChainId();
    /**
     * @notice Thrown when an invalid source address is encountered.
     */
    error InvalidSourceAddress();
    /**
     * @notice Thrown when received message timestamp is less than the last processed timestamp.
     */
    error OutdatedSyncMessage();

    /**
     * @notice A function to get the Wormhole relayer address.
     * @return The address of the Wormhole relayer.
     */
    function getWormholeRelayer() external view returns (address);

    /**
     * @notice A function to get the source subscriptions synchronizer address.
     * @return The address of the source subscriptions synchronizer.
     */
    function getSourceSubscriptionsSynchronizer() external view returns (address);

    /**
     * @notice A function to get the source chain ID.
     * @return The ID of the source chain.
     */
    function getSourceChainId() external view returns (uint16);

    /**
     * @notice A function to get the latest synced Sparse Merkle Tree root.
     * @return _smtRoot The latest synced SMT root.
     */
    function getLatestSyncedSMTRoot() external view returns (bytes32);

    /**
     * @notice A function to check if a given SMT root exists in the history.
     * @param smtRoot_ The SMT root to check.
     * @return `true` if the root exists in history, `false` otherwise.
     */
    function rootInHistory(bytes32 smtRoot_) external view returns (bool);
}
