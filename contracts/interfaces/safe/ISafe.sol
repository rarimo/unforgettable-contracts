// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

/**
 * @title ISafe
 * @notice The minimal interface for the `Safe` contract
 *         (https://github.com/safe-global/safe-smart-account/blob/main/contracts/Safe.sol)
 */
interface ISafe {
    /**
     * @notice Execute `operation_` to `to_` with native token `value_`.
     * @param to_ Destination address of the module transaction.
     * @param value_ Native token value of the module transaction.
     * @param data_ Data payload of the module transaction.
     * @param operation_ Operation type of the module transaction: 0 for `CALL` and 1 for `DELEGATECALL`.
     * @return success_ Boolean flag indicating if the call succeeded.
     */
    function execTransactionFromModule(
        address to_,
        uint256 value_,
        bytes memory data_,
        Enum.Operation operation_
    ) external returns (bool success_);

    /**
     * @notice Replaces the owner `oldOwner` in the Safe with `newOwner`.
     * @dev This can only be done via a Safe transaction.
     *      ⚠️⚠️⚠️ A Safe can set itself as an owner which is a valid setup for EIP-7702 delegations.
     *      However, if address of the accounts is not an EOA and cannot sign for itself, you can
     *      potentially block access to the account completely. For example, if you have a `n/n`
     *      Safe (so `threshold == ownerCount`) and one of the owners is the Safe itself and not
     *      an EIP-7702 delegated account, then it will not be possible to produce a valid
     *      signature for the Safe. ⚠️⚠️⚠️
     * @param prevOwner_ Owner that pointed to the `oldOwner_` to be replaced in the linked list.
     *        If the owner to be replaced is the first (or only) element of the list,
     *        `prevOwner_` MUST be set to the sentinel address `0x1` (referred to as
     *        `SENTINEL_OWNERS` in the implementation).
     * @param oldOwner_ Owner address to be replaced.
     * @param newOwner_ New owner address.
     */
    function swapOwner(address prevOwner_, address oldOwner_, address newOwner_) external;

    /**
     * @notice Returns if `owner_` is an owner of the Safe.
     * @return Boolean if `owner_` is an owner of the Safe.
     */
    function isOwner(address owner_) external view returns (bool);

    /**
     * @notice Reads `length_` bytes of storage in the current contract
     * @param offset_ The offset in the current contract's storage in words to start reading from.
     * @param length_ The number of words (32 bytes) of data to read.
     * @return The bytes that were read.
     */
    function getStorageAt(uint256 offset_, uint256 length_) external view returns (bytes memory);
}
