// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ISubscriptionManager} from "../../interfaces/core/ISubscriptionManager.sol";
import {ITokensPaymentModule} from "../../interfaces/core/subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "../../interfaces/core/subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "../../interfaces/core/subscription/ISignatureSubscriptionModule.sol";

import {SBTPaymentModule} from "./modules/SBTPaymentModule.sol";
import {TokensPaymentModule} from "./modules/TokensPaymentModule.sol";
import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";

contract BaseSubscriptionManager is
    ISubscriptionManager,
    TokensPaymentModule,
    SBTPaymentModule,
    SignatureSubscriptionModule,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 private constant BASE_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.subscription.manager.storage");

    struct BaseSubscriptionManagerStorage {
        address recoveryManager;
    }

    modifier onlyRecoveryManager() {
        _onlyRecoveryManager();
        _;
    }

    modifier onlySubscriptionActivator() {
        _onlySubscriptionActivator();
        _;
    }

    function _getBaseSubscriptionManagerStorage()
        private
        pure
        returns (BaseSubscriptionManagerStorage storage _bsms)
    {
        bytes32 slot_ = BASE_SUBSCRIPTION_MANAGER_STORAGE_SLOT;

        assembly ("memory-safe") {
            _bsms.slot := slot_
        }
    }

    function __BaseSubscriptionManager_init(
        address recoveryManager_,
        TokensPaymentModuleInitData calldata tokensPaymentInitData_,
        SBTPaymentModuleInitData calldata sbtPaymentInitData_,
        SigSubscriptionModuleInitData calldata sigSubscriptionInitData_
    ) public onlyInitializing {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        _setRecoveryManager(recoveryManager_);

        __TokensPaymentModule_init(tokensPaymentInitData_);
        __SBTPaymentModule_init(sbtPaymentInitData_);
        __SignatureSubscriptionModule_init(sigSubscriptionInitData_);
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function updatePaymentTokens(
        PaymentTokenUpdateEntry[] calldata paymentTokenEntries_
    ) public virtual onlyOwner {
        for (uint256 i = 0; i < paymentTokenEntries_.length; ++i) {
            _updatePaymentToken(
                paymentTokenEntries_[i].paymentToken,
                paymentTokenEntries_[i].baseSubscriptionCost
            );
        }
    }

    function removePaymentTokens(address[] calldata tokensToRemove_) public virtual onlyOwner {
        for (uint256 i = 0; i < tokensToRemove_.length; ++i) {
            _removePaymentToken(tokensToRemove_[i]);
        }
    }

    function updateDurationFactor(uint64 duration_, uint256 factor_) public virtual onlyOwner {
        _updateDurationFactor(duration_, factor_);
    }

    function withdrawTokens(
        address tokenAddr_,
        address to_,
        uint256 amount_
    ) public virtual onlyOwner nonReentrant {
        _withdrawTokens(tokenAddr_, to_, amount_);
    }

    function updateSBTs(SBTUpdateEntry[] calldata sbtEntries_) public virtual onlyOwner {
        for (uint256 i = 0; i < sbtEntries_.length; ++i) {
            _updateSBT(sbtEntries_[i].sbt, sbtEntries_[i].subscriptionDurationPerToken);
        }
    }

    function removeSBTs(address[] calldata sbtsToRemove_) public virtual onlyOwner {
        for (uint256 i = 0; i < sbtsToRemove_.length; ++i) {
            _removeSBT(sbtsToRemove_[i]);
        }
    }

    function setSubscriptionSigner(address newSigner_) public virtual onlyOwner {
        _setSubscriptionSigner(newSigner_);
    }

    function activateSubscription(address account_) public virtual onlySubscriptionActivator {
        _activateSubscription(account_);
    }

    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    ) public payable virtual override(TokensPaymentModule, ITokensPaymentModule) nonReentrant {
        super.buySubscription(account_, token_, duration_);
    }

    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        uint256 tokenId_
    ) public virtual override(SBTPaymentModule, ISBTPaymentModule) nonReentrant {
        super.buySubscriptionWithSBT(vault_, sbt_, tokenId_);
    }

    function buySubscriptionWithSignature(
        address vault_,
        uint64 duration_,
        bytes memory signature_
    )
        public
        virtual
        override(SignatureSubscriptionModule, ISignatureSubscriptionModule)
        nonReentrant
    {
        super.buySubscriptionWithSignature(vault_, duration_, signature_);
    }

    function getRecoveryManager() public view virtual returns (address) {
        return _getBaseSubscriptionManagerStorage().recoveryManager;
    }

    function isSubscriptionActivator(address account_) public view returns (bool) {
        return account_ == getRecoveryManager();
    }

    function _setRecoveryManager(address recoveryManager_) internal virtual {
        _checkAddress(recoveryManager_, "RecoveryManager");

        _getBaseSubscriptionManagerStorage().recoveryManager = recoveryManager_;

        emit RecoveryManagerUpdated(recoveryManager_);
    }

    function _activateSubscription(address account_) internal virtual {
        require(!hasSubscription(account_), SubscriptionAlreadyActivated(account_));

        _extendSubscription(account_, 0);

        emit SubscriptionActivated(account_, block.timestamp);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _onlyRecoveryManager() internal view {
        require(msg.sender == getRecoveryManager(), NotARecoveryManager(msg.sender));
    }

    function _onlySubscriptionActivator() internal view {
        require(isSubscriptionActivator(msg.sender), NotASubscriptionActivator(msg.sender));
    }
}
