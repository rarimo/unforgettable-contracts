// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISubscriptionsSynchronizer} from "../../interfaces/crosschain/ISubscriptionsSynchronizer.sol";
import {SparseMerkleTree} from "@solarity/solidity-lib/libs/data-structures/SparseMerkleTree.sol";

contract SubscriptionsSynchronizerMock is ISubscriptionsSynchronizer {
    function saveSubscriptionData(address, uint64, uint64, bool) external override {}

    function sync(uint16) external payable override {}

    function getSubscriptionsSMTRoot() external pure override returns (bytes32) {}

    function getSubscriptionsSMTProof(
        address,
        address
    ) external pure override returns (SparseMerkleTree.Proof memory) {}

    function getWormholeRelayer() public view returns (address) {}

    function getCrossChainTxGasLimit() public view returns (uint256) {}

    function getSubscriptionManagers() public view returns (address[] memory) {}

    function getTargetAddress(uint16 chainId_) public view returns (address) {}

    function isChainSupported(uint16 chainId_) external pure override returns (bool) {}
}
