// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/access/Ownable.sol";

contract NftMimeTypes is Ownable {
    mapping(string => bool) public validMimeTypes;
    mapping(uint256 => string) private _mimeTypes;

    constructor() {
        setValidMimeType("image", true);
        setValidMimeType("video", true);
        setValidMimeType("audio", true);
        setValidMimeType("model", true);
        setValidMimeType("other", true);
    }

    /**
     * Sets a MIME type as valid/invalid.
     */
    function setValidMimeType(string memory mimeType_, bool valid) public onlyOwner {
        validMimeTypes[mimeType_] = valid;
    }

    /**
     * Gets MIME type of a certain token.
     */
    function mimeType(uint256 tokenId) external view returns (string memory) {
        return _mimeTypes[tokenId];
    }

    /**
     * Sets MIME type for a certain token.
     */
    function _setMimeType(uint256 tokenId, string calldata mimeType_) internal {
        require(validMimeTypes[mimeType_], "NftMimeTypes: MIME type not valid");
        _mimeTypes[tokenId] = mimeType_;
    }
}
