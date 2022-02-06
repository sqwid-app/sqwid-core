// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interface/INftMutableUri.sol";

/**
 * Implementation of the EIP-2981 for NFT royalties https://eips.ethereum.org/EIPS/eip-2981
 */
contract NftMutableUri is INftMutableUri, ERC165 {
    mapping(uint256 => bool) private _mutableUriMapping;

    /**
     * Returns whether or not a token has mutable URI.
     */
    function hasMutableURI(uint256 tokenId) public view override returns (bool mutableUri) {
        return _mutableUriMapping[tokenId];
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
            interfaceId == type(INftMutableUri).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * Sets whether a token has mutable URI or not.
     */
    function _setMutableURI(uint256 tokenId, bool mutableUri) internal {
        _mutableUriMapping[tokenId] = mutableUri;
    }
}
