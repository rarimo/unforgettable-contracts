// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@wormhole/interfaces/IWormholeRelayer.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ADeployerGuard} from "@solarity/solidity-lib/utils/ADeployerGuard.sol";

import {IRecoveryManager} from "../interfaces/core/IRecoveryManager.sol";

contract MessageSender is ADeployerGuard, OwnableUpgradeable {
    uint256 constant GAS_LIMIT = 50000; // Adjust the gas limit as needed

    bytes32 public constant WORMHOLE_MESSAGE_SENDER_STORAGE_SLOT =
        keccak256("unforgettable.contract.wormhole.message.sender.storage");

    struct MessageSenderStorage {
        IWormholeRelayer wormholeRelayer;
        IRecoveryManager recoveryProvider;
    }

    event WormholeRelayerUpdated(address indexed relayer);
    event RecoveryProviderUpdated(address indexed recoveryProvider);

    error NotSubscriptionManager();
    error ZeroAddr(string fieldName);
    error InsufficientFundsForCrossChainDelivery();

    modifier onlySubscriptionManager() {
        require(
            _getMSStorage().recoveryProvider.subscriptionManagerExists(msg.sender),
            NotSubscriptionManager()
        );

        _;
    }

    constructor() ADeployerGuard(msg.sender) {
        _disableInitializers();
    }

    function _getMSStorage() private pure returns (MessageSenderStorage storage _ms) {
        bytes32 slot_ = WORMHOLE_MESSAGE_SENDER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _ms.slot := slot_
        }
    }

    function initialize(
        address wormholeRelayer_,
        address recoveryProvider_
    ) external initializer onlyDeployer {
        __Ownable_init(msg.sender);

        _updateWormholeRelayer(wormholeRelayer_);
        _updateRecoveryProvider(recoveryProvider_);
    }

    function sendMessage(
        uint16 targetChain_,
        address targetAddress_,
        bytes memory message_
    ) external payable {
        uint256 _cost = quoteCrossChainCost(targetChain_); // Dynamically calculate the cross-chain cost

        require(msg.value >= _cost, InsufficientFundsForCrossChainDelivery());

        _getMSStorage().wormholeRelayer.sendPayloadToEvm{value: _cost}(
            targetChain_,
            targetAddress_,
            message_,
            0, // No receiver value needed
            GAS_LIMIT // Gas limit for the transaction
        );
    }

    function quoteCrossChainCost(uint16 targetChain_) public view returns (uint256 _cost) {
        (_cost, ) = _getMSStorage().wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain_,
            0,
            GAS_LIMIT
        );
    }

    function updateWormholeRelayer(address wormholeRelayer_) public onlyOwner {
        _checkAddress(wormholeRelayer_, "WormholeRelayer");

        _updateWormholeRelayer(wormholeRelayer_);

        emit WormholeRelayerUpdated(wormholeRelayer_);
    }

    function updateRecoveryProvider(address recoveryProvider_) public onlyOwner {
        _checkAddress(recoveryProvider_, "RecoveryProvider");

        _updateRecoveryProvider(recoveryProvider_);

        emit RecoveryProviderUpdated(recoveryProvider_);
    }

    function _updateWormholeRelayer(address wormholeRelayer_) internal {
        _getMSStorage().wormholeRelayer = IWormholeRelayer(wormholeRelayer_);
    }

    function _updateRecoveryProvider(address recoveryProvider_) internal {
        _getMSStorage().recoveryProvider = IRecoveryManager(recoveryProvider_);
    }

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }
}
