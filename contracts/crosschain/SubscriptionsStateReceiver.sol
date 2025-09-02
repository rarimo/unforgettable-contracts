// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";
import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {ISubscriptionsStateReceiver} from "../interfaces/crosschain/ISubscriptionsStateReceiver.sol";

contract SubscriptionsStateReceiver is
    ISubscriptionsStateReceiver,
    OwnableUpgradeable,
    ADeployerGuard
{
    bytes32 public constant SUBSCRIPTIONS_STATE_RECEIVER_STORAGE_SLOT =
        keccak256("unforgettable.contract.subscriptions.receiver.storage");

    struct SubscriptionsStateReceiverStorage {
        address wormholeRelayer;
        uint16 sourceChainId;
        address sourceSubscriptionsSynchronizer;
        mapping(bytes32 subscriptionsSMTRoot => uint256) SMTRootsHistory;
    }

    event MessageReceived(bytes message);
    event WormholeRelayerUpdated(address indexed relayer);
    event SubscriptionsSynchronizerUpdated(address indexed synchronizer);
    event SourceChainIdUpdated(uint16 indexed chainId);

    error NotWormholeRelayer(address);
    error ZeroAddr(string fieldName);
    error InvalidSourceChainId();
    error InvalidSourceAddress();
    error OutdatedSyncMessage();

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
        SubscriptionsStateReceiverInitData memory initData_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateWormholeRelayer(initData_.wormholeRelayer);
        _updateSubscriptionsSynchronizer(initData_.subscriptionsSynchronizer);
        _updateSourceChainId(initData_.sourceChainId);
    }

    function _getSSRStorage()
        private
        pure
        returns (SubscriptionsStateReceiverStorage storage _ssrs)
    {
        bytes32 slot_ = SUBSCRIPTIONS_STATE_RECEIVER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _ssrs.slot := slot_
        }
    }

    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _updateWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    function updateSubscriptionsSynchronizer(
        address subscriptionStateSynchronizer_
    ) public onlyOwner {
        _updateSubscriptionsSynchronizer(subscriptionStateSynchronizer_);

        emit SubscriptionsSynchronizerUpdated(subscriptionStateSynchronizer_);
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
        SubscriptionsStateReceiverStorage storage $ = _getSSRStorage();

        require(sourceChain_ == $.sourceChainId, InvalidSourceChainId());
        require(
            address(bytes20(sourceAddress_)) == $.sourceSubscriptionsSynchronizer,
            InvalidSourceAddress()
        );

        SyncMessage memory _msg = _decodeMessage(payload_);

        _processMessage(_msg);

        emit MessageReceived(payload_);
    }

    function rootInHistory(bytes32 smtRoot_) public view returns (bool) {
        return _getSSRStorage().SMTRootsHistory[smtRoot_] > 0;
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _getSSRStorage().wormholeRelayer = wormholeRelayer_;
    }

    function _updateSubscriptionsSynchronizer(address subscriptionsSynchronizer_) internal {
        _checkAddress(subscriptionsSynchronizer_, "SubscriptionsSynchronizer");

        _getSSRStorage().sourceSubscriptionsSynchronizer = subscriptionsSynchronizer_;
    }

    function _updateSourceChainId(uint16 sourceChainId_) internal {
        require(sourceChainId_ != 0 && sourceChainId_ != block.chainid, InvalidSourceChainId());

        _getSSRStorage().sourceChainId = sourceChainId_;
    }

    function _processMessage(SyncMessage memory message_) internal {
        SubscriptionsStateReceiverStorage storage $ = _getSSRStorage();

        require(
            $.SMTRootsHistory[message_.subscriptionsSMTRoot] < message_.syncTimestamp,
            OutdatedSyncMessage()
        );

        $.SMTRootsHistory[message_.subscriptionsSMTRoot] = message_.syncTimestamp;
    }

    function _decodeMessage(bytes memory message_) internal pure returns (SyncMessage memory) {
        return abi.decode(message_, (SyncMessage));
    }

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
