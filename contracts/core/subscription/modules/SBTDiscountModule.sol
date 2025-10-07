// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {PERCENTAGE_100} from "@solarity/solidity-lib/utils/Globals.sol";

import {IBurnableSBT} from "../../../interfaces/tokens/IBurnableSBT.sol";
import {ISBTDiscountModule} from "../../../interfaces/core/subscription/ISBTDiscountModule.sol";

abstract contract SBTDiscountModule is ISBTDiscountModule {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct SBTDiscountModuleStorage {
        EnumerableMap.AddressToUintMap sbtDiscounts;
    }

    bytes32 private constant SBT_DISCOUNT_MODULE_STORAGE_SLOT =
        keccak256("unforgettable.contract.sbt.discount.module.storage");

    function _getSBTDiscountModuleStorage()
        private
        pure
        returns (SBTDiscountModuleStorage storage _sdms)
    {
        bytes32 slot_ = SBT_DISCOUNT_MODULE_STORAGE_SLOT;

        assembly ("memory-safe") {
            _sdms.slot := slot_
        }
    }

    /// @inheritdoc ISBTDiscountModule
    function getDiscountSBTs() external view returns (address[] memory) {
        return _getSBTDiscountModuleStorage().sbtDiscounts.keys();
    }

    /// @inheritdoc ISBTDiscountModule
    function getDiscount(address sbt_) public view returns (uint256 discount_) {
        (, discount_) = _getSBTDiscountModuleStorage().sbtDiscounts.tryGet(sbt_);
    }

    function _updateDiscount(address sbt_, uint256 discount_) internal {
        require(discount_ <= PERCENTAGE_100, InvalidDiscountValue(discount_));

        if (discount_ == 0) {
            _getSBTDiscountModuleStorage().sbtDiscounts.remove(sbt_);
        } else {
            _getSBTDiscountModuleStorage().sbtDiscounts.set(sbt_, discount_);
        }

        emit DiscountUpdated(sbt_, discount_);
    }

    function _validateDiscount(DiscountData memory discount_) internal view {
        require(
            _getSBTDiscountModuleStorage().sbtDiscounts.contains(discount_.sbtAddr),
            InvalidDiscountSBT(discount_.sbtAddr)
        );

        require(
            IBurnableSBT(discount_.sbtAddr).ownerOf(discount_.tokenId) == msg.sender,
            NotADiscountSBTOwner(discount_.sbtAddr, msg.sender, discount_.tokenId)
        );
    }

    function _applyDiscount(uint256 amount_, uint256 discount_) internal pure returns (uint256) {
        if (discount_ == 0) {
            return amount_;
        }

        return Math.mulDiv(amount_, PERCENTAGE_100 - discount_, PERCENTAGE_100);
    }
}
