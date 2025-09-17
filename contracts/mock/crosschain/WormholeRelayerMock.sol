// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract WormholeRelayerMock {
    function sendPayloadToEvm(
        uint16 targetChain_,
        address targetAddress_,
        bytes calldata payload_,
        uint256 receiverValue_,
        uint256 gasLimit_
    ) external payable returns (uint64) {}

    function quoteEVMDeliveryPrice(
        uint16 targetChain_,
        uint256 receiverValue_,
        uint256 gasLimit_
    ) external view returns (uint256 _nativePriceQuote, uint256 _targetChainRefundPerGasUnused) {
        return (100 wei, 0);
    }
}
