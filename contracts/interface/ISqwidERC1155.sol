// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IRoyaltyInfo.sol";

interface ISqwidERC1155 is IERC2981 {
    function mint(
        address to,
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetada
    ) external returns (uint256);

    function mintBatch(
        address to,
        uint256[] memory amounts,
        string[] memory tokenURIs,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues,
        bool[] memory mutableMetadatas
    ) external returns (uint256[] memory);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);
}
