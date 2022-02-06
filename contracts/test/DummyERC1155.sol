//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../../@openzeppelin/contracts/utils/Counters.sol";
import "../base/NftRoyalties.sol";

contract DummyERC1155 is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC1155("fake-uri") {}

    function mint(address owner, uint256 amount) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(owner, newItemId, amount, "");

        return newItemId;
    }
}
