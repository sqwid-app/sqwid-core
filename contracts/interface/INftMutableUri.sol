// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface INftMutableUri is IERC165 {
    function hasMutableURI(uint256 tokenId) external view returns (bool mutableUri);
}
