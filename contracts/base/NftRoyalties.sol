// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interface/INftRoyalties.sol";

/**
 * Implementation of the EIP-2981 for NFT royalties https://eips.ethereum.org/EIPS/eip-2981
 */
contract NftRoyalties is ERC165, INftRoyalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }

    uint256 public constant MAX_ROYALTY_VALUE = 5000;

    mapping(uint256 => RoyaltyInfo) private _royalties;

    /**
     * Returns royalties recipient and amount for a certain token and sale value,
     * following EIP-2981 guidelines (https://eips.ethereum.org/EIPS/eip-2981).
     */
    function royaltyInfo(uint256 tokenId, uint256 saleValue)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = _royalties[tokenId];
        return (royalty.recipient, (saleValue * royalty.amount) / 10000);
    }

    /**
     * Returns whether or not the contract supports a certain interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(INftRoyalties).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * Sets token royalties recipient and percentage value (with two decimals) for a certain token.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint256 value
    ) internal {
        require(value <= MAX_ROYALTY_VALUE, "NftRoyalties: Royalties higher than 5000");
        _royalties[tokenId] = RoyaltyInfo(recipient, uint24(value));
    }
}
