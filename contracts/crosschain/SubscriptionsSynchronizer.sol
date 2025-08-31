// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {ISubscriptionManager} from "../interfaces/core/ISubscriptionManager.sol";
import {ISubscriptionsSynchronizer} from "../interfaces/crosschain/ISubscriptionsSynchronizer.sol";

contract SubscriptionsSynchronizer is
    ISubscriptionsSynchronizer,
    ADeployerGuard,
    OwnableUpgradeable
{
    using SparseMerkleTree for SparseMerkleTree.Bytes32SMT;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant GAS_LIMIT = 50000; // Adjust the gas limit as needed

    bytes32 public constant SUBSCRIPTIONS_SYNCHRONIZER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscriptions.synchronizer.storage");

    struct SubscriptionSynchronizerStorage {
        IWormholeRelayer wormholeRelayer;
        SparseMerkleTree.Bytes32SMT subscriptionsSMT;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint16 chainId => address) targetAddresses;
    }

    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionManagerAdded(address indexed subscriptionManager);
    event SubscriptionManagerRemoved(address indexed subscriptionManager);
    event DestinationAdded(uint16 indexed chainId, address indexed targetAddress);
    event DestinationRemoved(uint16 indexed chainId);

    error NotSubscriptionManager();
    error ZeroAddr(string fieldName);
    error InsufficientFundsForCrossChainDelivery();
    error ChainNotSupported(uint16 chainId);
    error InvalidChainId(uint16 chainId);
    error DestinationAlreadyExists(uint16 chainId, address targetAddress);

    modifier onlySubscriptionManager() {
        require(
            _getSSSStorage().subscriptionManagers.contains(msg.sender),
            NotSubscriptionManager()
        );

        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getSSSStorage() private pure returns (SubscriptionSynchronizerStorage storage _sss) {
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

        address[] calldata _subscriptionManagers = initData_.subscriptionManagers;

        for (uint256 i; i < _subscriptionManagers.length; ++i) {
            _addSubscriptionManager(_subscriptionManagers[i]);
        }

        Destination[] calldata _destinations = initData_.destinations;

        for (uint256 i; i < _destinations.length; ++i) {
            _addDestination(_destinations[i]);
        }
    }

    function getSubscriptionsSMTRoot() public view returns (bytes32) {
        return _getSSSStorage().subscriptionsSMT.getRoot();
    }

    function getSubscriptionsSMTProof(
        address subscriptionManager_,
        address account_
    ) public view returns (SparseMerkleTree.Proof memory) {
        return
            _getSSSStorage().subscriptionsSMT.getProof(
                keccak256(abi.encode(subscriptionManager_, account_))
            );
    }

    function sync(uint16 targetChain_) external payable {
        SubscriptionSynchronizerStorage storage $ = _getSSSStorage();

        address _targetAddress = $.targetAddresses[targetChain_];

        require(_targetAddress != address(0), ChainNotSupported(targetChain_));

        uint256 _cost = quoteCrossChainCost(targetChain_); // Dynamically calculate the cross-chain cost

        require(msg.value >= _cost, InsufficientFundsForCrossChainDelivery());

        bytes memory _message = _constructMessage();

        $.wormholeRelayer.sendPayloadToEvm{value: _cost}(
            targetChain_,
            _targetAddress,
            _message,
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
        bytes32 _key = keccak256(abi.encode(msg.sender, account_));
        bytes32 _value = keccak256(abi.encode(msg.sender, account_, startTime_, endTime_));

        if (isNewSubscription_) {
            _addSMTNode(_key, _value);
        } else {
            _updateSMTNode(_key, _value);
        }
    }

    function quoteCrossChainCost(uint16 targetChain_) public view returns (uint256 _cost) {
        (_cost, ) = _getSSSStorage().wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain_,
            0,
            GAS_LIMIT
        );
    }

    function isChainSupported(uint16 chainId_) public view returns (bool) {
        return _getSSSStorage().targetAddresses[chainId_] != address(0);
    }

    function _initializeSubscriptionsSMT(uint32 maxDepth_) internal {
        _getSSSStorage().subscriptionsSMT.initialize(maxDepth_);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _getSSSStorage().wormholeRelayer = IWormholeRelayer(wormholeRelayer_);
    }

    function _addSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSSStorage().subscriptionManagers.add(subscriptionManager_);
    }

    function _addDestination(Destination calldata destination_) internal {
        SubscriptionSynchronizerStorage storage $ = _getSSSStorage();

        uint16 _chainId = destination_.chainId;
        address _targetAddress = destination_.targetAddress;

        _checkAddress(_targetAddress, "TargetAddress");
        require(_chainId != 0 && _chainId != block.chainid, InvalidChainId(_chainId));
        require(
            $.targetAddresses[_chainId] == address(0),
            DestinationAlreadyExists(_chainId, _targetAddress)
        );

        $.targetAddresses[_chainId] = _targetAddress;
    }

    function _removeSubscriptionManager(address subscriptionManager_) internal {
        _checkAddress(subscriptionManager_, "SubscriptionManager");

        _getSSSStorage().subscriptionManagers.remove(subscriptionManager_);
    }

    function _removeDestination(uint16 chainId_) internal {
        require(chainId_ != 0 && chainId_ != block.chainid, InvalidChainId(chainId_));

        SubscriptionSynchronizerStorage storage $ = _getSSSStorage();

        address _targetAddress = $.targetAddresses[chainId_];

        require(_targetAddress != address(0), ChainNotSupported(chainId_));

        delete $.targetAddresses[chainId_];
    }

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
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
        _getSSSStorage().subscriptionsSMT.add(key_, value_);
    }

    function _updateSMTNode(bytes32 key_, bytes32 value_) internal {
        _getSSSStorage().subscriptionsSMT.update(key_, value_);
    }
}
