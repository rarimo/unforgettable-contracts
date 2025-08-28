// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

interface ISafe {
    function execTransactionFromModule(
        address to_,
        uint256 value_,
        bytes memory data_,
        Enum.Operation operation_
    ) external returns (bool success_);

    function swapOwner(address prevOwner_, address oldOwner_, address newOwner_) external;

    function isOwner(address owner_) external view returns (bool);

    function getStorageAt(uint256 offset_, uint256 length_) external view returns (bytes memory);
}
