// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

import {IBaseSideChainSubscriptionManager} from "../../interfaces/core/IBaseSideChainSubscriptionManager.sol";
import {ISubscriptionsStateReceiver} from "../../interfaces/crosschain/ISubscriptionsStateReceiver.sol";
import {BaseSubscriptionModule} from "./modules/BaseSubscriptionModule.sol";

abstract contract BaseSideChainSubscriptionManager is
    IBaseSideChainSubscriptionManager,
    BaseSubscriptionModule,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant BASE_SIDECHAIN_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.sidechain.subscription.manager.storage");

    struct BaseSideChainSubscriptionManagerStorage {
        ISubscriptionsStateReceiver subscriptionsStateReceiver;
        address sourceSubscriptionManager;
    }

    function _getBaseSideChainSubscriptionManagerStorage()
        private
        pure
        returns (BaseSideChainSubscriptionManagerStorage storage _bscsms)
    {
        bytes32 slot_ = BASE_SIDECHAIN_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _bscsms.slot := slot_
        }
    }

    function __BaseSideChainSubscriptionManager_init(
        BaseSideChainSubscriptionManagerInitData memory initData_
    ) public onlyInitializing {
        __Ownable_init(msg.sender);

        _setSubscriptionsStateReceiver(initData_.subscriptionsStateReceiver);
        _setSourceSubscriptionManager(initData_.sourceSubscriptionManager);
    }

    /**
     * @notice A function to set a new SubscriptionsStateReceiver contract.
     * @param subscriptionsStateReceiver_ The address of the SubscriptionsStateReceiver contract.
     */
    function setSubscriptionsStateReceiver(
        address subscriptionsStateReceiver_
    ) external onlyOwner {
        _setSubscriptionsStateReceiver(subscriptionsStateReceiver_);
    }

    /**
     * @notice A function to set a new source SubscriptionManager contract.
     * @param sourceSubscriptionManager_ The address of the source SubscriptionManager contract.
     */
    function setSourceSubscriptionManager(address sourceSubscriptionManager_) external onlyOwner {
        _setSourceSubscriptionManager(sourceSubscriptionManager_);
    }

    /// @inheritdoc IBaseSideChainSubscriptionManager
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @inheritdoc IBaseSideChainSubscriptionManager
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    /// @inheritdoc IBaseSideChainSubscriptionManager
    function syncSubscription(
        address account_,
        AccountSubscriptionData calldata subscriptionData_,
        SparseMerkleTree.Proof calldata proof_
    ) public virtual whenNotPaused nonReentrant {
        _verifyProof(account_, subscriptionData_, proof_);

        _setStartTime(account_, subscriptionData_.startTime);

        if (subscriptionData_.endTime > getSubscriptionEndTime(account_)) {
            _setEndTime(account_, subscriptionData_.endTime);
        }

        emit SubscriptionSynced(account_, subscriptionData_.startTime, subscriptionData_.endTime);
    }

    /// @inheritdoc IBaseSideChainSubscriptionManager
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function _setSubscriptionsStateReceiver(address subscriptionsStateReceiver_) internal {
        _checkAddress(subscriptionsStateReceiver_, "SubscriptionsStateReceiver");

        _getBaseSideChainSubscriptionManagerStorage()
            .subscriptionsStateReceiver = ISubscriptionsStateReceiver(subscriptionsStateReceiver_);

        emit SubscriptionsStateReceiverUpdated(subscriptionsStateReceiver_);
    }

    function _setSourceSubscriptionManager(address sourceSubscriptionManager_) internal {
        _checkAddress(sourceSubscriptionManager_, "SourceSubscriptionManager");

        _getBaseSideChainSubscriptionManagerStorage()
            .sourceSubscriptionManager = sourceSubscriptionManager_;

        emit SourceSubscriptionManagerUpdated(sourceSubscriptionManager_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _verifyProof(
        address account_,
        AccountSubscriptionData calldata subscriptionData,
        SparseMerkleTree.Proof calldata proof_
    ) internal view {
        BaseSideChainSubscriptionManagerStorage
            storage $ = _getBaseSideChainSubscriptionManagerStorage();

        require(
            proof_.key == keccak256(abi.encode($.sourceSubscriptionManager, account_)),
            InvalidProofKey()
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
            InvalidProofValue()
        );

        bytes32 root_ = SparseMerkleTree.processProof(_hash2, _hash3, proof_);

        require($.subscriptionsStateReceiver.rootInHistory(root_), UnknownRoot(root_));
    }

    function _hash2(bytes32 a_, bytes32 b_) private pure returns (bytes32 result_) {
        assembly {
            mstore(0, a_)
            mstore(32, b_)

            result_ := keccak256(0, 64)
        }
    }

    function _hash3(bytes32 a_, bytes32 b_, bytes32 c) private pure returns (bytes32 result_) {
        assembly {
            let freePtr_ := mload(64)

            mstore(freePtr_, a_)
            mstore(add(freePtr_, 32), b_)
            mstore(add(freePtr_, 64), c)

            result_ := keccak256(freePtr_, 96)
        }
    }
}
