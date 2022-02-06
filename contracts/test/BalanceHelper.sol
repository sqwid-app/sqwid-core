// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * If we use 'ReefToken.balanceOf(address)' we are getting the Subsrate and EVM combined balance,
 * as its contract is multi-currency mutant.
 * We can use this util contract to get just the EVM balance of an address.
 */
contract BalanceHelper {
    function balanceOf(address addr) external view returns (uint256) {
        return address(addr).balance;
    }
}
