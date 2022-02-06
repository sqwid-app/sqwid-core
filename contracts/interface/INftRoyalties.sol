// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * Interface for royalties following EIP-2981 (https://eips.ethereum.org/EIPS/eip-2981).
 */
interface INftRoyalties is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
