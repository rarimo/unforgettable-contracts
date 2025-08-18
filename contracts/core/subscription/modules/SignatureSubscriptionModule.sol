// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {ISignatureSubscriptionModule} from "../../../interfaces/core/ISignatureSubscriptionModule.sol";

import {EIP712SignatureChecker} from "../../../libs/EIP712SignatureChecker.sol";

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

contract SignatureSubscriptionModule is
    ISignatureSubscriptionModule,
    BaseSubscriptionModule,
    Initializable,
    NoncesUpgradeable,
    EIP712Upgradeable
{
    using EIP712SignatureChecker for address;

    bytes32 public constant BUY_SUBSCRIPTION_TYPEHASH =
        keccak256("BuySubscription(address sender,uint64 duration,uint256 nonce)");

    bytes32 private constant SIGNATURE_SUBSCRIPTION_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.sig.subscription.module.storage");

    struct SignatureSubscriptionModuleStorage {
        address subscriptionSigner;
    }

    function _getSignatureSubscriptionModuleStorage()
        private
        pure
        returns (SignatureSubscriptionModuleStorage storage _ssms)
    {
        bytes32 slot_ = SIGNATURE_SUBSCRIPTION_MODULE_STORAGE_SLOT;

        assembly {
            _ssms.slot := slot_
        }
    }

    function __SignatureSubscriptionModule_init(
        address subscriptionSigner_
    ) public onlyInitializing {
        __EIP712_init("SignatureSubscriptionModule", "v1.0.0");

        _setSubscriptionSigner(subscriptionSigner_);
    }

    function buySubscriptionWithSignature(
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) external {
        _buySubscriptionWithSignature(msg.sender, account_, duration_, signature_);
    }

    function getSubscriptionSigner() external view returns (address) {
        return _getSignatureSubscriptionModuleStorage().subscriptionSigner;
    }

    function hashBuySubscription(
        address sender_,
        uint64 duration_,
        uint256 nonce_
    ) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(BUY_SUBSCRIPTION_TYPEHASH, sender_, duration_, nonce_))
            );
    }

    function _setSubscriptionSigner(address newSubscriptionSigner_) internal virtual {
        _checkAddress(newSubscriptionSigner_, "SubscriptionSigner");

        _getSignatureSubscriptionModuleStorage().subscriptionSigner = newSubscriptionSigner_;

        emit SubscriptionSignerUpdated(newSubscriptionSigner_);
    }

    function _buySubscriptionWithSignature(
        address sender_,
        address account_,
        uint64 duration_,
        bytes memory signature_
    ) internal virtual {
        SignatureSubscriptionModuleStorage storage $ = _getSignatureSubscriptionModuleStorage();

        uint256 currentNonce_ = _useNonce(sender_);
        bytes32 buySubscriptionHash_ = hashBuySubscription(sender_, duration_, currentNonce_);

        $.subscriptionSigner.checkSignature(buySubscriptionHash_, signature_);

        _extendSubscription(account_, duration_);

        emit SubscriptionBoughtWithSignature(sender_, duration_, currentNonce_);
    }
}
