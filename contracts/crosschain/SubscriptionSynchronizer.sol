// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWormholeRelayer} from "@wormhole/interfaces/IWormholeRelayer.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {ISubscriptionSynchronizer} from "../interfaces/crosschain/ISubscriptionSynchronizer.sol";

contract SubscriptionSynchronizer is
    ISubscriptionSynchronizer,
    ADeployerGuard,
    OwnableUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant GAS_LIMIT = 50000; // Adjust the gas limit as needed

    bytes32 public constant SUBSCRIPTION_SYNCHRONIZER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscription.synchronizer.storage");

    struct SubscriptionSynchronizerStorage {
        IWormholeRelayer wormholeRelayer;
        EnumerableSet.AddressSet subscriptionManagers;
        mapping(uint16 chainId => address) targetAddresses;
    }

    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionManagerAdded(address indexed subscriptionManager);
    event DestinationAdded(uint16 indexed chainId, address indexed targetAddress);

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
        bytes32 slot_ = SUBSCRIPTION_SYNCHRONIZER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _sss.slot := slot_
        }
    }

    function initialize(
        SubscriptionSynchronizerInitData calldata initData_
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

    function sync(uint16 targetChain_) external payable {
        SubscriptionSynchronizerStorage storage $ = _getSSSStorage();

        address _targetAddress = $.targetAddresses[targetChain_];

        require(_targetAddress != address(0), ChainNotSupported(targetChain_));

        uint256 _cost = quoteCrossChainCost(targetChain_); // Dynamically calculate the cross-chain cost

        require(msg.value >= _cost, InsufficientFundsForCrossChainDelivery());

        // TODO: construct message
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

    function addDestination(Destination calldata destination_) public onlyOwner {
        _addDestination(destination_);

        emit DestinationAdded(destination_.chainId, destination_.targetAddress);
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

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }

    function _constructMessage() internal pure returns (bytes memory) {
        return abi.encode(keccak256("Hello, Wormhole!")); // Placeholder message
    }
}
