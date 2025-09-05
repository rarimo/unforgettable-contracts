// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ISideChainSubscriptionManager} from "../../interfaces/core/ISideChainSubscriptionManager.sol";
import {ISubscriptionsStateReceiver} from "../../interfaces/crosschain/ISubscriptionsStateReceiver.sol";
import {BaseSubscriptionModule} from "./modules/BaseSubscriptionModule.sol";

contract SideChainSubscriptionManager is
    ISideChainSubscriptionManager,
    BaseSubscriptionModule,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant SIDECHAIN_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.sidechain.subscription.manager.storage");

    struct SideChainSubscriptionManagerStorage {
        ISubscriptionsStateReceiver subscriptionsStateReceiver;
        address sourceSubscriptionManager;
    }

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
    }

    function setSourceSubscriptionManager(address sourceSubscriptionManager_) external onlyOwner {
        _setSourceSubscriptionManager(sourceSubscriptionManager_);
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function syncSubscription(
        address account_,
        AccountSubscriptionData calldata subscriptionData_,
        bytes32[] calldata proof_
    ) public virtual {
        _verifyProof(account_, subscriptionData_, proof_);

        _setStartTime(account_, subscriptionData_.startTime);
        _setEndTime(account_, subscriptionData_.endTime);

        emit SubscriptionSynced(account_, subscriptionData_.startTime, subscriptionData_.endTime);
    }

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function _setSubscriptionsStateReceiver(address subscriptionsStateReceiver_) internal {
        _checkAddress(subscriptionsStateReceiver_, "SubscriptionsStateReceiver");

        _getSideChainSubscriptionManagerStorage()
            .subscriptionsStateReceiver = ISubscriptionsStateReceiver(subscriptionsStateReceiver_);

        emit SubscriptionsStateReceiverUpdated(subscriptionsStateReceiver_);
    }

    function _setSourceSubscriptionManager(address sourceSubscriptionManager_) internal {
        _checkAddress(sourceSubscriptionManager_, "SourceSubscriptionManager");

        _getSideChainSubscriptionManagerStorage()
            .sourceSubscriptionManager = sourceSubscriptionManager_;

        emit SourceSubscriptionManagerUpdated(sourceSubscriptionManager_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _verifyProof(
        address account_,
        AccountSubscriptionData calldata subscriptionData,
        bytes32[] calldata proof_
    ) internal view {
        SideChainSubscriptionManagerStorage storage $ = _getSideChainSubscriptionManagerStorage();

        bytes32 key_ = keccak256(abi.encode($.sourceSubscriptionManager, account_));
        bytes32 value_ = keccak256(
            abi.encode(
                $.sourceSubscriptionManager,
                account_,
                subscriptionData.startTime,
                subscriptionData.endTime
            )
        );

        bytes32 computedHash_ = _hash3(key_, value_, bytes32(uint256(1)));
        uint256 pathIndex_ = uint256(key_);
        uint256 depth_ = proof_.length;

        while (depth_ > 0 && proof_[depth_ - 1] == bytes32(0)) {
            --depth_;
        }

        for (uint256 i = depth_; i > 0; --i) {
            uint256 sIndex_ = i - 1;

            if ((pathIndex_ >> sIndex_) & 1 == 1) {
                computedHash_ = _hash2(proof_[sIndex_], computedHash_);
            } else {
                computedHash_ = _hash2(computedHash_, proof_[sIndex_]);
            }
        }

        require(
            $.subscriptionsStateReceiver.rootInHistory(computedHash_),
            UknownRoot(computedHash_)
        );
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
