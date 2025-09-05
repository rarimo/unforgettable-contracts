// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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

    uint256 constant GAS_LIMIT = 50_000; // Adjust the gas limit as needed

    bytes32 public constant SUBSCRIPTIONS_SYNCHRONIZER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscriptions.synchronizer.storage");

    struct SubscriptionSynchronizerStorage {
        IWormholeRelayer wormholeRelayer;
        SparseMerkleTree.Bytes32SMT subscriptionsSMT;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint16 chainId => address) targetAddresses;
    }

    modifier onlySubscriptionManager() {
        require(
            _getSSStorage().subscriptionManagers.contains(msg.sender),
            NotSubscriptionManager()
        );

        _;
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
            GAS_LIMIT // Gas limit for the transaction
        );
    }

    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _updateWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    function addSubscriptionManager(address subscriptionManager_) public onlyOwner {
        _addSubscriptionManager(subscriptionManager_);

        emit SubscriptionManagerAdded(subscriptionManager_);
    }

    function removeSubscriptionManager(address subscriptionManager_) public onlyOwner {
        _removeSubscriptionManager(subscriptionManager_);

        emit SubscriptionManagerRemoved(subscriptionManager_);
    }

    function addDestination(Destination calldata destination_) public onlyOwner {
        _addDestination(destination_);

        emit DestinationAdded(destination_.chainId, destination_.targetAddress);
    }

    function removeDestination(uint16 chainId_) public onlyOwner {
        _removeDestination(chainId_);

        emit DestinationRemoved(chainId_);
    }

    function saveSubscriptionData(
        address account_,
        uint64 startTime_,
        uint64 endTime_,
        bool isNewSubscription_
    ) public onlySubscriptionManager {
        bytes32 key_ = _key(msg.sender, account_);
        bytes32 value_ = _value(msg.sender, account_, startTime_, endTime_);

        if (isNewSubscription_) {
            _addSMTNode(key_, value_);
        } else {
            _updateSMTNode(key_, value_);
        }
    }

    function quoteCrossChainCost(uint16 targetChain_) public view returns (uint256 _cost) {
        (_cost, ) = _getSSStorage().wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain_,
            0,
            GAS_LIMIT
        );
    }

    function isChainSupported(uint16 chainId_) public view returns (bool) {
        return _getSSStorage().targetAddresses[chainId_] != address(0);
    }

    function getSubscriptionsSMTRoot() public view returns (bytes32) {
        return _getSSStorage().subscriptionsSMT.getRoot();
    }

    function getSubscriptionsSMTProof(
        address subscriptionManager_,
        address account_
    ) public view returns (bytes32[] memory) {
        return
            _getSSStorage()
                .subscriptionsSMT
                .getProof(_key(subscriptionManager_, account_))
                .siblings;
    }

    function _initializeSubscriptionsSMT(uint32 maxDepth_) internal {
        _getSSStorage().subscriptionsSMT.initialize(maxDepth_);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _getSSStorage().wormholeRelayer = IWormholeRelayer(wormholeRelayer_);
    }

    function _addSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSStorage().subscriptionManagers.add(subscriptionManager_);
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
    }

    function _removeSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSStorage().subscriptionManagers.remove(subscriptionManager_);
    }

    function _removeDestination(uint16 chainId_) internal {
        SubscriptionSynchronizerStorage storage $ = _getSSStorage();

        address targetAddress_ = $.targetAddresses[chainId_];

        require(targetAddress_ != address(0), ChainNotSupported(chainId_));

        delete $.targetAddresses[chainId_];
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
