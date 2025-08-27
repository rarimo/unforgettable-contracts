// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {ISubscriptionStateReceiver} from "../interfaces/crosschain/ISubscriptionStateReceiver.sol";

contract SubscriptionStateReceiver is
    ISubscriptionStateReceiver,
    OwnableUpgradeable,
    ADeployerGuard
{
    bytes32 public constant SUBSCRIPTION_STATE_RECEIVER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscription.receiver.storage");

    struct SubscriptionStateReceiverStorage {
        address wormholeRelayer;
        address subscriptionStateSynchronizer;
        uint16 sourceChainId;
    }

    event MessageReceived(bytes message);
    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionStateSynchronizerUpdated(address indexed synchronizer);
    event SourceChainIdUpdated(uint16 indexed chainId);

    error NotWormholeRelayer(address);
    error ZeroAddr(string fieldName);
    error InvalidSourceChainId();
    error InvalidSourceAddress();

    modifier onlyWormholeRelayer() {
        require(
            address(_getSSRStorage().wormholeRelayer) == msg.sender,
            NotWormholeRelayer(msg.sender)
        );

        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(
        SubscriptionStateReceiverInitData memory initData_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateWormholeRelayer(initData_.wormholeRelayer);
        _updateSubscriptionStateSynchronizer(initData_.subscriptionStateSynchronizer);
        _updateSourceChainId(initData_.sourceChainId);
    }

    function _getSSRStorage()
        private
        pure
        returns (SubscriptionStateReceiverStorage storage _ssrs)
    {
        bytes32 slot_ = SUBSCRIPTION_STATE_RECEIVER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _ssrs.slot := slot_
        }
    }

    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _updateWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    function updateSubscriptionStateSynchronizer(
        address subscriptionStateSynchronizer_
    ) public onlyOwner {
        _updateSubscriptionStateSynchronizer(subscriptionStateSynchronizer_);

        emit SubscriptionStateSynchronizerUpdated(subscriptionStateSynchronizer_);
    }

    function updateSourceChainId(uint16 sourceChainId_) public onlyOwner {
        _updateSourceChainId(sourceChainId_);

        emit SourceChainIdUpdated(sourceChainId_);
    }

    function receiveWormholeMessages(
        bytes memory payload_,
        bytes[] memory, // additional VAAs (optional, not needed here)
        bytes32 sourceAddress_,
        uint16 sourceChain_,
        bytes32 // delivery hash
    ) public payable override onlyWormholeRelayer {
        SubscriptionStateReceiverStorage storage $ = _getSSRStorage();

        require(sourceChain_ == $.sourceChainId, InvalidSourceChainId());
        require(
            address(uint160(uint256(sourceAddress_))) == $.subscriptionStateSynchronizer,
            InvalidSourceAddress()
        );

        // Decode the payload to extract the message

        emit MessageReceived(payload_);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _getSSRStorage().wormholeRelayer = wormholeRelayer_;
    }

    function _updateSubscriptionStateSynchronizer(
        address subscriptionStateSynchronizer_
    ) internal {
        _checkAddress(subscriptionStateSynchronizer_, "SubscriptionStateSynchronizer");

        _getSSRStorage().subscriptionStateSynchronizer = subscriptionStateSynchronizer_;
    }

    function _updateSourceChainId(uint16 sourceChainId_) internal {
        require(sourceChainId_ != 0 && sourceChainId_ != block.chainid, InvalidSourceChainId());

        _getSSRStorage().sourceChainId = sourceChainId_;
    }

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
