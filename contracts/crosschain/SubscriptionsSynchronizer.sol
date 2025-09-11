// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";
import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {ISubscriptionManager} from "../interfaces/core/ISubscriptionManager.sol";
import {ISubscriptionsSynchronizer} from "../interfaces/crosschain/ISubscriptionsSynchronizer.sol";

import {ZeroAddressChecker} from "../utils/ZeroAddressChecker.sol";

contract SubscriptionsSynchronizer is
    ISubscriptionsSynchronizer,
    ADeployerGuard,
    OwnableUpgradeable,
    ZeroAddressChecker
{
    using SparseMerkleTree for SparseMerkleTree.Bytes32SMT;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    bytes32 public constant SUBSCRIPTIONS_SYNCHRONIZER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscriptions.synchronizer.storage");

    struct SubscriptionSynchronizerStorage {
        IWormholeRelayer wormholeRelayer;
        uint256 crossChainTxGasLimit;
        SparseMerkleTree.Bytes32SMT subscriptionsSMT;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint16 chainId => address) targetAddresses;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getSSStorage() private pure returns (SubscriptionSynchronizerStorage storage _sss) {
        bytes32 slot_ = SUBSCRIPTIONS_SYNCHRONIZER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _sss.slot := slot_
        }
    }

    function initialize(
        SubscriptionsSynchronizerInitData calldata initData_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateWormholeRelayer(initData_.wormholeRelayer);
        _setCrossChainTxGasLimit(initData_.crossChainTxGasLimit);
        _initializeSubscriptionsSMT(initData_.SMTMaxDepth);

        address[] calldata subscriptionManagers_ = initData_.subscriptionManagers;

        for (uint256 i; i < subscriptionManagers_.length; ++i) {
            _addSubscriptionManager(subscriptionManagers_[i]);
        }

        Destination[] calldata destinations_ = initData_.destinations;

        for (uint256 i; i < destinations_.length; ++i) {
            _addDestination(destinations_[i]);
        }
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function sync(uint16 targetChain_) external payable {
        SubscriptionSynchronizerStorage storage $ = _getSSStorage();

        address targetAddress_ = $.targetAddresses[targetChain_];

        require(targetAddress_ != address(0), ChainNotSupported(targetChain_));

        uint256 _cost = quoteCrossChainCost(targetChain_); // Dynamically calculate the cross-chain cost

        require(msg.value >= _cost, InsufficientFundsForCrossChainDelivery());

        bytes memory message_ = _constructMessage();

        $.wormholeRelayer.sendPayloadToEvm{value: _cost}(
            targetChain_,
            targetAddress_,
            message_,
            0, // No receiver value needed
            $.crossChainTxGasLimit // Gas limit for the transaction
        );

        uint256 excess_ = msg.value - _cost;

        if (excess_ > 0) {
            Address.sendValue(payable(msg.sender), excess_);
        }

        emit SyncInitiated(block.timestamp);
    }

    /**
     * @notice A function to update the Wormhole Relayer contract address.
     * @param wormholeRelayer_ The address of the new Wormhole Relayer contract
     */
    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _updateWormholeRelayer(wormholeRelayer_);
    }

    /**
     * @notice A function to add a new subscription manager.
     * @param subscriptionManager_ The address of the subscription manager to add.
     */
    function addSubscriptionManager(address subscriptionManager_) public onlyOwner {
        _addSubscriptionManager(subscriptionManager_);
    }

    /**
     * @notice A function to remove a subscription manager.
     * @param subscriptionManager_ The address of the subscription manager to remove.
     */
    function removeSubscriptionManager(address subscriptionManager_) public onlyOwner {
        _removeSubscriptionManager(subscriptionManager_);
    }

    /**
     * @notice A function to add a new destination.
     * @param destination_ The destination to add.
     */
    function addDestination(Destination calldata destination_) public onlyOwner {
        _addDestination(destination_);
    }

    /**
     * @notice A function to remove a destination.
     * @param chainId_ The ID of the chain to remove the destination for.
     */
    function removeDestination(uint16 chainId_) public onlyOwner {
        _removeDestination(chainId_);
    }

    /**
     * @notice A function to set the gas limit for cross-chain transactions.
     * @param gasLimit_ The new gas limit for cross-chain transactions.
     */
    function setCrossChainTxGasLimit(uint256 gasLimit_) public onlyOwner {
        _setCrossChainTxGasLimit(gasLimit_);
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function saveSubscriptionData(
        address account_,
        uint64 startTime_,
        uint64 endTime_,
        bool isNewSubscription_
    ) public {
        _authSubscriptionManager();

        bytes32 key_ = _key(msg.sender, account_);
        bytes32 value_ = _value(msg.sender, account_, startTime_, endTime_);

        if (isNewSubscription_) {
            _addSMTNode(key_, value_);
        } else {
            _updateSMTNode(key_, value_);
        }
    }

    /**
     * @notice A function to quote the cost of a cross-chain transaction.
     * @param targetChain_ The ID of the target chain.
     * @return _cost The quoted cost for the cross-chain transaction.
     */
    function quoteCrossChainCost(uint16 targetChain_) public view returns (uint256 _cost) {
        (_cost, ) = _getSSStorage().wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain_,
            0,
            _getSSStorage().crossChainTxGasLimit
        );
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getWormholeRelayer() public view returns (address) {
        return address(_getSSStorage().wormholeRelayer);
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getCrossChainTxGasLimit() public view returns (uint256) {
        return _getSSStorage().crossChainTxGasLimit;
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getSubscriptionManagers() public view returns (address[] memory) {
        return _getSSStorage().subscriptionManagers.values();
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getTargetAddress(uint16 chainId_) public view returns (address) {
        return _getSSStorage().targetAddresses[chainId_];
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function isChainSupported(uint16 chainId_) public view returns (bool) {
        return _getSSStorage().targetAddresses[chainId_] != address(0);
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getSubscriptionsSMTRoot() public view returns (bytes32) {
        return _getSSStorage().subscriptionsSMT.getRoot();
    }

    /// @inheritdoc ISubscriptionsSynchronizer
    function getSubscriptionsSMTProof(
        address subscriptionManager_,
        address account_
    ) public view returns (SparseMerkleTree.Proof memory) {
        return _getSSStorage().subscriptionsSMT.getProof(_key(subscriptionManager_, account_));
    }

    function _initializeSubscriptionsSMT(uint32 maxDepth_) internal {
        _getSSStorage().subscriptionsSMT.initialize(maxDepth_);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _getSSStorage().wormholeRelayer = IWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    function _addSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSStorage().subscriptionManagers.add(subscriptionManager_);

        emit SubscriptionManagerAdded(subscriptionManager_);
    }

    function _addDestination(Destination calldata destination_) internal {
        SubscriptionSynchronizerStorage storage $ = _getSSStorage();

        uint16 chainId_ = destination_.chainId;
        address targetAddress_ = destination_.targetAddress;

        _checkAddress(targetAddress_, "TargetAddress");

        require(chainId_ != 0 && chainId_ != block.chainid, InvalidChainId(chainId_));
        require(
            $.targetAddresses[chainId_] == address(0),
            DestinationAlreadyExists(chainId_, targetAddress_)
        );

        $.targetAddresses[chainId_] = targetAddress_;

        emit DestinationAdded(destination_.chainId, destination_.targetAddress);
    }

    function _removeSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSStorage().subscriptionManagers.remove(subscriptionManager_);

        emit SubscriptionManagerRemoved(subscriptionManager_);
    }

    function _removeDestination(uint16 chainId_) internal {
        SubscriptionSynchronizerStorage storage $ = _getSSStorage();

        address targetAddress_ = $.targetAddresses[chainId_];

        require(targetAddress_ != address(0), ChainNotSupported(chainId_));

        delete $.targetAddresses[chainId_];

        emit DestinationRemoved(chainId_);
    }

    function _setCrossChainTxGasLimit(uint256 gasLimit_) internal {
        _getSSStorage().crossChainTxGasLimit = gasLimit_;

        emit CrossChainTxGasLimitUpdated(gasLimit_);
    }

    function _constructMessage() internal view returns (bytes memory) {
        return
            abi.encode(
                SyncMessage({
                    syncTimestamp: block.timestamp,
                    subscriptionsSMTRoot: getSubscriptionsSMTRoot()
                })
            );
    }

    function _addSMTNode(bytes32 key_, bytes32 value_) internal {
        _getSSStorage().subscriptionsSMT.add(key_, value_);
    }

    function _updateSMTNode(bytes32 key_, bytes32 value_) internal {
        _getSSStorage().subscriptionsSMT.update(key_, value_);
    }

    function _authSubscriptionManager() private view {
        require(
            _getSSStorage().subscriptionManagers.contains(msg.sender),
            NotSubscriptionManager(msg.sender)
        );
    }

    function _key(address subscriptionManager_, address account_) private pure returns (bytes32) {
        return keccak256(abi.encode(subscriptionManager_, account_));
    }

    function _value(
        address subscriptionManager_,
        address account_,
        uint64 startTime_,
        uint64 endTime_
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(subscriptionManager_, account_, startTime_, endTime_));
    }
}
