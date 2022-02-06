// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISqwidERC1155 {
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

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function wrapERC721(address extNftContract, uint256 extTokenId) external returns (uint256);

    function wrapERC1155(
        address extNftContract,
        uint256 extTokenId,
        uint256 amount
    ) external returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);
}
