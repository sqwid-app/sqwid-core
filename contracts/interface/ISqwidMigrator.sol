// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISqwidMigrator {
    function positionClosed(
        uint256 positionId,
        address receiver,
        bool saleCreated
    ) external;
}
