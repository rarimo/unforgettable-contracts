// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBaseSubscriptionModule} from "./IBaseSubscriptionModule.sol";

/**
 * @title ISBTDiscountModule
 * @notice Interface for the SBTDiscountModule contract
 */
interface ISBTDiscountModule is IBaseSubscriptionModule {
    /**
     * @notice Data structure storing data used to update the SBT discounts configuration.
     * @param sbtAddr The address of the SBT contract associated with the discount.
     * @param discount The discount percentage value applied to subscription costs.
     */
    struct SBTDiscountUpdateEntry {
        address sbtAddr;
        uint256 discount;
    }

    /**
     * @notice Thrown when an unsupported SBT address is provided for a discount operation.
     * @param sbt The invalid SBT contract address.
     */
    error InvalidDiscountSBT(address sbt);
    /**
     * @notice Thrown when the caller doesn't own the provided discount SBT.
     * @param sbt The SBT contract address.
     * @param account The address attempting to claim the discount.
     */
    error NotADiscountSBTOwner(address sbt, address account);
    /**
     * @notice Thrown when a provided discount value is invalid (exceeds 100%).
     * @param discount The invalid discount value.
     */
    error InvalidDiscountValue(uint256 discount);

    /**
     * @notice Emitted when a discount percentage for a given discount SBT is updated.
     * @param sbt The address of the SBT associated with the discount.
     * @param discount The updated discount percentage value.
     */
    event DiscountUpdated(address indexed sbt, uint256 discount);

    /**
     * @notice A function to retrieve the list of all supported SBTs providing subscription discounts.
     * @return An array of supported discount SBT contract addresses.
     */
    function getDiscountSBTs() external view returns (address[] memory);

    /**
     * @notice A function to retrieve the discount percentage associated with a given SBT.
     * @param sbt_ The address of the SBT contract to query.
     * @return The discount percentage value applied for subscriptions using the given SBT.
     */
    function getDiscount(address sbt_) external view returns (uint256);
}
