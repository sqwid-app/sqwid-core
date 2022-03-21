// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract GasBurner {
    fallback() external payable {
        uint256 i;
        while (true) {
            i++;
        }
    }
}
