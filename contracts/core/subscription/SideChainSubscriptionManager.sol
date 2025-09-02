// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {ISideChainSubscriptionManager} from "../../interfaces/core/ISideChainSubscriptionManager.sol";
import {ISubscriptionsStateReceiver} from "../../interfaces/crosschain/ISubscriptionsStateReceiver.sol";

contract SideChainSubscriptionManager is
    ISideChainSubscriptionManager,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using MerkleProof for bytes32[];

    bytes32 private constant SIDECHAIN_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.sidechain.subscription.manager.storage");

    struct SideChainSubscriptionManagerStorage {
        ISubscriptionsStateReceiver subscriptionsStateReceiver;
        address sourceSubscriptionManager;
        mapping(address => AccountSubscriptionData) accountsSubscriptionData;
    }

    event SubscriptionSynced(address indexed account, uint64 startTime, uint64 endTime);
    event SubscriptionsStateReceiverUpdated(address indexed subscriptionsStateReceiver);
    event SourceSubscriptionManagerUpdated(address indexed sourceSubscriptionManager);

    error UknownRoot(bytes32 root);
    error InvalidSMTKey();
    error InvalidSMTValue();
    error InvalidSMTProof();

    function _getSideChainSubscriptionManagerStorage()
        private
        pure
        returns (SideChainSubscriptionManagerStorage storage _scsms)
    {
        bytes32 slot_ = SIDECHAIN_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _scsms.slot := slot_
        }
    }

    function __SideChainSubscriptionManager_init(
        SideChainSubscriptionManagerInitData memory initData_
    ) public onlyInitializing {
        __Ownable_init(msg.sender);

        _setSubscriptionsStateReceiver(initData_.subscriptionsStateReceiver);
        _setSourceSubscriptionManager(initData_.sourceSubscriptionManager);
    }

    function setSubscriptionsStateReceiver(
        address subscriptionsStateReceiver_
    ) external onlyOwner {
        _setSubscriptionsStateReceiver(subscriptionsStateReceiver_);

        emit SubscriptionsStateReceiverUpdated(subscriptionsStateReceiver_);
    }

    function setSourceSubscriptionManager(address sourceSubscriptionManager_) external onlyOwner {
        _setSourceSubscriptionManager(sourceSubscriptionManager_);

        emit SourceSubscriptionManagerUpdated(sourceSubscriptionManager_);
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function syncSubscription(
        address account_,
        AccountSubscriptionData calldata subscriptionData,
        SparseMerkleTree.Proof calldata proof_
    ) public virtual {
        SideChainSubscriptionManagerStorage storage $ = _getSideChainSubscriptionManagerStorage();

        require($.subscriptionsStateReceiver.rootInHistory(proof_.root), UknownRoot(proof_.root));
        require(
            proof_.key == keccak256(abi.encode($.sourceSubscriptionManager, account_)),
            InvalidSMTKey()
        );
        require(
            proof_.value ==
                keccak256(
                    abi.encode(
                        $.sourceSubscriptionManager,
                        account_,
                        subscriptionData.startTime,
                        subscriptionData.endTime
                    )
                ),
            InvalidSMTValue()
        );
        require(proof_.siblings.verify(proof_.root, proof_.value), InvalidSMTProof());

        $.accountsSubscriptionData[account_] = subscriptionData;

        emit SubscriptionSynced(account_, subscriptionData.startTime, subscriptionData.endTime);
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function hasSubscription(address account_) public view virtual returns (bool) {
        return getSubscriptionStartTime(account_) > 0;
    }

    function hasActiveSubscription(address account_) public view virtual returns (bool) {
        return block.timestamp < getSubscriptionEndTime(account_);
    }

    function hasSubscriptionDebt(address account_) public view virtual returns (bool) {
        return !hasActiveSubscription(account_) && hasSubscription(account_);
    }

    function getSubscriptionStartTime(address account_) public view virtual returns (uint64) {
        return _getAccountSubscriptionData(account_).startTime;
    }

    function getSubscriptionEndTime(address account_) public view virtual returns (uint64) {
        if (!hasSubscription(account_)) {
            return uint64(block.timestamp);
        }

        return _getAccountSubscriptionData(account_).endTime;
    }

    function _setSubscriptionsStateReceiver(address subscriptionsStateReceiver_) internal {
        _checkAddress(subscriptionsStateReceiver_, "SubscriptionsStateReceiver");

        SideChainSubscriptionManagerStorage storage $ = _getSideChainSubscriptionManagerStorage();
        $.subscriptionsStateReceiver = ISubscriptionsStateReceiver(subscriptionsStateReceiver_);
    }

    function _setSourceSubscriptionManager(address sourceSubscriptionManager_) internal {
        _checkAddress(sourceSubscriptionManager_, "SourceSubscriptionManager");

        SideChainSubscriptionManagerStorage storage $ = _getSideChainSubscriptionManagerStorage();
        $.sourceSubscriptionManager = sourceSubscriptionManager_;
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _checkAddress(address addr_, string memory fieldName_) internal pure {
        require(addr_ != address(0), ZeroAddr(fieldName_));
    }

    function _getAccountSubscriptionData(
        address account_
    ) private view returns (AccountSubscriptionData storage) {
        return _getSideChainSubscriptionManagerStorage().accountsSubscriptionData[account_];
    }
}
