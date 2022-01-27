// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * Implementation of the EIP-2981 for NFT royalties https://eips.ethereum.org/EIPS/eip-2981
 */
contract NftRoyalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }

    // bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 internal constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    mapping(uint256 => RoyaltyInfo) private _royalties;

    /**
     * Returns royalties recipient and amount for a certain token and sale value,
     * following EIP-2981 guidelines (https://eips.ethereum.org/EIPS/eip-2981).
     */
    function royaltyInfo(uint256 tokenId, uint256 saleValue)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = _royalties[tokenId];
        return (royalty.recipient, (saleValue * royalty.amount) / 10000);
    }

    /**
     * Sets token royalties recipient and percentage value (with two decimals) for a certain token.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint256 value
    ) internal {
        require(value <= 5000, "NftRoyalties: Royalties value cannot be higher than 5000.");
        _royalties[tokenId] = RoyaltyInfo(recipient, uint24(value));
    }
}
