// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@wormhole/interfaces/IWormholeRelayer.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

contract WhMessageReceiver is IWormholeReceiver, OwnableUpgradeable, ADeployerGuard {
    bytes32 public constant WORMHOLE_MESSAGE_RECEIVER_STORAGE_SLOT =
        keccak256("unforgettable.contract.wormhole.message.receiver.storage");

    struct MessageReceiverStorage {
        IWormholeRelayer wormholeRelayer;
        mapping(uint16 => address) registeredEmitters; // emitterChainId => emitterAddress
    }

    event MessageReceived(bytes message);
    event WormholeRelayerUpdated(address indexed relayer);

    error NotWormholeRelayer(address);
    error EmitterNotRegistered(uint16 emitterChainId, bytes32 emitterAddress);
    error ZeroAddr(string fieldName);
    error InvalidChainId();

    modifier onlyRegisteredEmitter(uint16 emitterChainId, bytes32 emitterAddress) {
        require(
            _getMRStorage().registeredEmitters[emitterChainId] ==
                address(uint160(uint256(emitterAddress))),
            EmitterNotRegistered(emitterChainId, emitterAddress)
        );

        _;
    }

    modifier onlyWormholeRelayer() {
        require(
            address(_getMRStorage().wormholeRelayer) == msg.sender,
            NotWormholeRelayer(msg.sender)
        );

        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function initialize(address wormholeRelayer_) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateWormholeRelayer(wormholeRelayer_);
    }

    function _getMRStorage() private pure returns (MessageReceiverStorage storage _mr) {
        bytes32 slot_ = WORMHOLE_MESSAGE_RECEIVER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _mr.slot := slot_
        }
    }

    function registerEmitter(uint16 emitterChainId_, address emitterAddress_) public onlyOwner {
        require(emitterChainId_ != 0, InvalidChainId());
        _checkAddress(emitterAddress_, "EmitterAddress");

        _getMRStorage().registeredEmitters[emitterChainId_] = emitterAddress_;
    }

    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _updateWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    // Update receiveWormholeMessages to include the source address check
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additional VAAs (optional, not needed here)
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // delivery hash
    )
        public
        payable
        override
        onlyWormholeRelayer
        onlyRegisteredEmitter(sourceChain, sourceAddress)
    {
        MessageReceiverStorage storage $ = _getMRStorage();

        // Decode the payload to extract the message

        // Emit an event with the received message
        emit MessageReceived(payload);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _getMRStorage().wormholeRelayer = IWormholeRelayer(wormholeRelayer_);
    }

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
