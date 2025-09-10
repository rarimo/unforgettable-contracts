// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ISubscriptionManager} from "../../interfaces/core/ISubscriptionManager.sol";
import {ITokensPaymentModule} from "../../interfaces/core/subscription/ITokensPaymentModule.sol";
import {ISBTPaymentModule} from "../../interfaces/core/subscription/ISBTPaymentModule.sol";
import {ISignatureSubscriptionModule} from "../../interfaces/core/subscription/ISignatureSubscriptionModule.sol";

import {BaseSubscriptionModule} from "./modules/BaseSubscriptionModule.sol";
import {SBTPaymentModule} from "./modules/SBTPaymentModule.sol";
import {TokensPaymentModule} from "./modules/TokensPaymentModule.sol";
import {SignatureSubscriptionModule} from "./modules/SignatureSubscriptionModule.sol";
import {CrossChainModule} from "./modules/CrossChainModule.sol";

abstract contract BaseSubscriptionManager is
    ISubscriptionManager,
    TokensPaymentModule,
    SBTPaymentModule,
    SignatureSubscriptionModule,
    CrossChainModule,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 private constant BASE_SUBSCRIPTION_MANAGER_STORAGE_SLOT =
        keccak256("unforgettable.contract.base.subscription.manager.storage");

    struct BaseSubscriptionManagerStorage {
        EnumerableSet.AddressSet subscriptionCreators;
    }

    modifier onlySubscriptionCreator() {
        _onlySubscriptionCreator(msg.sender);
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
        address[] calldata subscriptionCreators_,
        TokensPaymentModuleInitData calldata tokensPaymentInitData_,
        SBTPaymentModuleInitData calldata sbtPaymentInitData_,
        SigSubscriptionModuleInitData calldata sigSubscriptionInitData_,
        CrossChainModuleInitData calldata crossChainInitData_
    ) public onlyInitializing {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        for (uint256 i = 0; i < subscriptionCreators_.length; ++i) {
            _addSubscriptionCreator(subscriptionCreators_[i]);
        }

        __TokensPaymentModule_init(tokensPaymentInitData_);
        __SBTPaymentModule_init(sbtPaymentInitData_);
        __SignatureSubscriptionModule_init(sigSubscriptionInitData_);
        __CrossChainModule_init(crossChainInitData_);
    }

    /// @inheritdoc ISubscriptionManager
    function pause() public virtual onlyOwner {
        _pause();
    }

    /// @inheritdoc ISubscriptionManager
    function unpause() public virtual onlyOwner {
        _unpause();
    }

    /**
     * @notice A function to update payment token configurations.
     * @param paymentTokenEntries_ An array of payment token configurations
              containing token addresses and their base costs.
     */
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

    /**
     * @notice A function to remove supported payment tokens.
     * @param tokensToRemove_ An array of token addresses to remove.
     */
    function removePaymentTokens(address[] calldata tokensToRemove_) public virtual onlyOwner {
        for (uint256 i = 0; i < tokensToRemove_.length; ++i) {
            _removePaymentToken(tokensToRemove_[i]);
        }
    }

    /**
     * @notice A function to update the duration-based factor for adjusting subscription costs.
     * @param duration_ Subscription duration to update the factor for.
     * @param factor_ Updated multiplicative factor applied to the base cost.
     */
    function updateDurationFactor(uint64 duration_, uint256 factor_) public virtual onlyOwner {
        _updateDurationFactor(duration_, factor_);
    }

    /**
     * @notice A function to withdraw tokens from the subscription manager.
     * @param tokenAddr_ Payment token address to withdraw.
     * @param to_ Withdrawal recipient address.
     * @param amount_ Amount of tokens to withdraw.
     */
    function withdrawTokens(
        address tokenAddr_,
        address to_,
        uint256 amount_
    ) public virtual onlyOwner nonReentrant {
        _withdrawTokens(tokenAddr_, to_, amount_);
    }

    /**
     * @notice A function to update supported SBTs used for subscription purchases.
     * @param sbtEntries_ An array of SBT configurations containing
              token addresses and their subscription durations.
     */
    function updateSBTs(SBTUpdateEntry[] calldata sbtEntries_) public virtual onlyOwner {
        for (uint256 i = 0; i < sbtEntries_.length; ++i) {
            _updateSBT(sbtEntries_[i].sbt, sbtEntries_[i].subscriptionDurationPerToken);
        }
    }

    /**
     * @notice A function to remove supported SBTs.
     * @param sbtsToRemove_ An array of SBT addresses to remove.
     */
    function removeSBTs(address[] calldata sbtsToRemove_) public virtual onlyOwner {
        for (uint256 i = 0; i < sbtsToRemove_.length; ++i) {
            _removeSBT(sbtsToRemove_[i]);
        }
    }

    /**
     * @notice A function to set a new subscription signer used for signature-based subscriptions.
     * @param newSigner_ Address of the new subscription signer.
     */
    function setSubscriptionSigner(address newSigner_) public virtual onlyOwner {
        _setSubscriptionSigner(newSigner_);
    }

    function setSubscriptionSynchronizer(
        address subscriptionSynchronizer_
    ) public virtual onlyOwner {
        _setSubscriptionSynchronizer(subscriptionSynchronizer_);
    }

    /// @inheritdoc ISubscriptionManager
    function createSubscription(address account_) public virtual onlySubscriptionCreator {
        _createSubscription(account_);
    }

    /// @inheritdoc ITokensPaymentModule
    function buySubscription(
        address account_,
        address token_,
        uint64 duration_
    )
        public
        payable
        virtual
        override(TokensPaymentModule, ITokensPaymentModule)
        nonReentrant
        whenNotPaused
    {
        super.buySubscription(account_, token_, duration_);
    }

    /// @inheritdoc ISBTPaymentModule
    function buySubscriptionWithSBT(
        address vault_,
        address sbt_,
        uint256 tokenId_
    ) public virtual override(SBTPaymentModule, ISBTPaymentModule) nonReentrant whenNotPaused {
        super.buySubscriptionWithSBT(vault_, sbt_, tokenId_);
    }

    /// @inheritdoc ISignatureSubscriptionModule
    function buySubscriptionWithSignature(
        address vault_,
        uint64 duration_,
        bytes memory signature_
    )
        public
        virtual
        override(SignatureSubscriptionModule, ISignatureSubscriptionModule)
        nonReentrant
        whenNotPaused
    {
        super.buySubscriptionWithSignature(vault_, duration_, signature_);
    }

    /// @inheritdoc ISubscriptionManager
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @inheritdoc ISubscriptionManager
    function getSubscriptionCreators() public view virtual returns (address[] memory) {
        return _getBaseSubscriptionManagerStorage().subscriptionCreators.values();
    }

    /// @inheritdoc ISubscriptionManager
    function isSubscriptionCreator(address account_) public view virtual returns (bool) {
        return _getBaseSubscriptionManagerStorage().subscriptionCreators.contains(account_);
    }

    function _addSubscriptionCreator(address subscriptionCreator_) internal virtual {
        _checkAddress(subscriptionCreator_, "SubscriptionCreator");

        require(
            _getBaseSubscriptionManagerStorage().subscriptionCreators.add(subscriptionCreator_),
            SubscriptionCreatorAlreadyAdded(subscriptionCreator_)
        );

        emit SubscriptionCreatorAdded(subscriptionCreator_);
    }

    function _removeSubscriptionCreator(address subscriptionCreator_) internal virtual {
        _onlySubscriptionCreator(subscriptionCreator_);

        _getBaseSubscriptionManagerStorage().subscriptionCreators.remove(subscriptionCreator_);

        emit SubscriptionCreatorRemoved(subscriptionCreator_);
    }

    function _createSubscription(address account_) internal virtual {
        require(!hasSubscription(account_), SubscriptionAlreadyCreated(account_));

        _extendSubscription(account_, 0);

        emit SubscriptionCreated(account_, block.timestamp);
    }

    function _extendSubscription(
        address account_,
        uint64 duration_
    ) internal virtual override(CrossChainModule, BaseSubscriptionModule) {
        super._extendSubscription(account_, duration_);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation_) internal override onlyOwner {}

    function _onlySubscriptionCreator(address creator_) internal view {
        require(isSubscriptionCreator(creator_), NotASubscriptionCreator(creator_));
    }
}
