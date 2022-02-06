//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../../@openzeppelin/contracts/utils/Counters.sol";
import "../base/NftRoyalties.sol";

contract DummyERC721Royalties is NftRoyalties, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Dummy Token With Royalties", "DUMMY-ROY") {}

    function mint(
        address owner,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(owner, newItemId);
        _setTokenURI(newItemId, tokenURI);
        if (royaltyValue > 0) {
            _setTokenRoyalty(newItemId, royaltyRecipient, royaltyValue);
        }

        return newItemId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(NftRoyalties, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
