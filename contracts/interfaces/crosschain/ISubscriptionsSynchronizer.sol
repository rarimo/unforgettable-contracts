// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {ISubscriptionMessanger} from "./ISubscriptionMessanger.sol";

/**
 * @title ISubscriptionsSynchronizer
 * @notice Interface for synchronizing subscriptions across chains.
 */
interface ISubscriptionsSynchronizer is ISubscriptionMessanger {
    /**
     * @notice Initialization data for the subscriptions synchronizer.
     * @param wormholeRelayer The address of the Wormhole relayer.
     * @param crossChainTxGasLimit The gas limit for cross-chain transactions.
     * @param SMTMaxDepth The maximum depth of the Sparse Merkle Tree.
     * @param subscriptionManagers The addresses of the subscription managers.
     * @param destinations The list of destination chains and their target addresses.
     */
    struct SubscriptionsSynchronizerInitData {
        address wormholeRelayer;
        uint256 crossChainTxGasLimit;
        uint32 SMTMaxDepth;
        address[] subscriptionManagers;
        Destination[] destinations;
    }

    /**
     * @notice Struct representing a destination chain and its target address.
     * @param chainId The ID of the destination chain.
     * @param targetAddress The target address on the destination chain.
     */
    struct Destination {
        uint16 chainId;
        address targetAddress;
    }

    /**
     * @notice Event emitted when a synchronization is initiated.
     * @param timestamp The timestamp of the synchronization.
     */
    event SyncInitiated(uint256 timestamp);
    /**
     * @notice Event emitted when the Wormhole relayer is updated.
     * @param relayer The address of the updated Wormhole relayer.
     */
    event WormholeRelayerUpdated(address indexed relayer);
    /**
     * @notice Event emitted when a subscription manager is added.
     * @param subscriptionManager The address of the added subscription manager.
     */
    event SubscriptionManagerAdded(address indexed subscriptionManager);
    /**
     * @notice Event emitted when a subscription manager is removed.
     * @param subscriptionManager The address of the removed subscription manager.
     */
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    /**
     * @notice Event emitted when a destination chain is added.
     * @param chainId The ID of the added destination chain.
     * @param targetAddress The target address on the added destination chain.
     */
    event DestinationAdded(uint16 indexed chainId, address indexed targetAddress);
    /**
     * @notice Event emitted when a destination chain is removed.
     * @param chainId The ID of the removed destination chain.
     */
    event DestinationRemoved(uint16 indexed chainId);
    /**
     * @notice Event emitted when the cross-chain transaction gas limit is updated.
     * @param gasLimit The updated gas limit.
     */
    event CrossChainTxGasLimitUpdated(uint256 gasLimit);

    /**
     * @notice Thrown when the caller is not a registered subscription manager.
     * @param caller The address of the caller.
     */
    error NotSubscriptionManager(address caller);
    /**
     * @notice Thrown when there are insufficient funds for cross-chain delivery.
     */
    error InsufficientFundsForCrossChainDelivery();
    /**
     * @notice Thrown when a chain is not supported.
     * @param chainId The ID of the unsupported chain.
     */
    error ChainNotSupported(uint16 chainId);
    /**
     * @notice Thrown when an invalid chain ID is encountered.
     * @param chainId The invalid chain ID.
     */
    error InvalidChainId(uint16 chainId);
    /**
     * @notice Thrown when a destination chain already exists.
     * @param chainId The ID of the existing destination chain.
     * @param targetAddress The target address of the existing destination chain.
     */
    error DestinationAlreadyExists(uint16 chainId, address targetAddress);

    /**
     * @notice A function to synchronize subscriptions to a target chain.
     * @param targetChain_ The ID of the target chain.
     */
    function sync(uint16 targetChain_) external payable;

    /**
     * @notice A function to save subscription data. Can only be called by a registered subscription manager.
     * @param account_ The account whose subscription data is being saved.
     * @param startTime_ The start time of the subscription.
     * @param endTime_ The end time of the subscription.
     * @param isNewSubscription_ A boolean indicating whether this is a new subscription.
     */
    function saveSubscriptionData(
        address account_,
        uint64 startTime_,
        uint64 endTime_,
        bool isNewSubscription_
    ) external;

    /**
     * @notice A function to get the root of the subscriptions Sparse Merkle Tree.
     * @return _smtRoot The root of the subscriptions SMT.
     */
    function getSubscriptionsSMTRoot() external view returns (bytes32 _smtRoot);

    /**
     * @notice A function to get the Sparse Merkle Tree proof for a specific account's subscription data.
     * @param subscriptionManager_ The address of the subscription manager.
     * @param account_ The account for which to get the SMT proof.
     * @return _proof The Sparse Merkle Tree proof.
     */
    function getSubscriptionsSMTProof(
        address subscriptionManager_,
        address account_
    ) external view returns (SparseMerkleTree.Proof memory _proof);

    /**
     * @notice A function to get wormhole relayer address.
     * @return _wormholeRelayer The wormhole relayer address.
     */
    function getWormholeRelayer() external view returns (address _wormholeRelayer);

    /**
     * @notice A function to get cross chain tx gas limit.
     * @return _gasLimit The gas limit.
     */
    function getCrossChainTxGasLimit() external view returns (uint256 _gasLimit);

    /**
     * @notice A function to get the registered subscription managers
     * @return _subscriptionManagers The registered subscription managers.
     */
    function getSubscriptionManagers()
        external
        view
        returns (address[] memory _subscriptionManagers);

    /**
     * @notice A function to get the target address for the specified chain ID.
     * @param chainId_ The chain ID.
     * @return _targetAddress The target address for the specified chain ID.
     */
    function getTargetAddress(uint16 chainId_) external view returns (address _targetAddress);

    /**
     * @notice A function to check if a specific chain is supported.
     * @param chainId_ The ID of the chain to check.
     * @return _supported A boolean indicating whether the chain is supported.
     */
    function isChainSupported(uint16 chainId_) external view returns (bool _supported);
}
