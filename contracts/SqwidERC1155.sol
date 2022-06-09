//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "../@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/Address.sol";
import "../@openzeppelin/contracts/utils/Context.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "./base/NftRoyalties.sol";
import "./base/NftMimeTypes.sol";
import "./base/SqwidERC1155Wrapper.sol";

contract SqwidERC1155 is Context, ERC165, IERC1155, NftRoyalties, NftMimeTypes, SqwidERC1155Wrapper {
    using Counters for Counters.Counter;
    using Address for address;

    Counters.Counter private _tokenIds;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(uint256 => address[]) private _owners;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _uris;
    mapping(bytes4 => bool) private _supportedInterfaces;

    /**
     * Mints a new token.
     */
    function mint(
        address to,
        uint256 amount,
        string memory tokenURI,
        string calldata mimeType_,
        address royaltyRecipient,
        uint256 royaltyValue
    ) public returns (uint256) {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(amount > 0, "ERC1155: amount has to be larger than 0");
        require(bytes(tokenURI).length > 0, "ERC1155: tokenURI has to be non-empty");

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        address operator = _msgSender();

        _balances[tokenId][to] += amount;
        _updateOwners(tokenId, address(0), to, 0, 0);
        emit TransferSingle(operator, address(0), to, tokenId, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, tokenId, amount, "");

        _uris[tokenId] = tokenURI;
        _setMimeType(tokenId, mimeType_);

        if (royaltyValue > 0) {
            _setTokenRoyalty(tokenId, royaltyRecipient, royaltyValue);
        }

        return tokenId;
    }

    /**
     * Mints new tokens in batch.
     */
    function mintBatch(
        address to,
        uint256[] memory amounts,
        string[] memory tokenURIs,
        string[] calldata mimeTypes,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues
    ) public returns (uint256[] memory) {
        require(to != address(0), "ERC1155: mint to the 0 address");
        require(
            amounts.length == royaltyRecipients.length &&
                amounts.length == tokenURIs.length &&
                amounts.length == mimeTypes.length &&
                amounts.length == royaltyValues.length,
            "ERC1155: Arrays length mismatch"
        );

        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            require(bytes(tokenURIs[i]).length > 0, "ERC1155: tokenURI has to be non-empty");
            _tokenIds.increment();
            ids[i] = _tokenIds.current();
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
            _updateOwners(ids[i], address(0), to, 0, 0);
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, "");

        for (uint256 i; i < ids.length; i++) {
            if (royaltyValues[i] > 0) {
                _setTokenRoyalty(ids[i], royaltyRecipients[i], royaltyValues[i]);
            }
            _uris[ids[i]] = tokenURIs[i];
            _setMimeType(ids[i], mimeTypes[i]);
        }

        return ids;
    }

    /**
     * Returns token ids owned by an address.
     */
    function getTokensByOwner(address owner) public view returns (uint256[] memory) {
        uint256[] memory tokens = new uint256[](_tokenIds.current() + 1);
        for (uint256 i = 1; i <= _tokenIds.current(); i++) {
            uint256 balance = balanceOf(owner, i);
            if (balance > 0) {
                tokens[i] = balance;
            }
        }
        return tokens;
    }

    /**
     * Returns total supply of a token.
     */
    function getTokenSupply(uint256 _id) public view returns (uint256) {
        uint256 tokenSupply = 0;
        for (uint256 i = 0; i < getOwners(_id).length; i++) {
            if (getOwners(_id)[i] != address(0)) {
                tokenSupply += balanceOf(getOwners(_id)[i], _id);
            }
        }
        return tokenSupply;
    }

    /**
     * Returns the URI for a specific token by its id.
     */
    function uri(uint256 tokenId) public view returns (string memory) {
        return _uris[tokenId];
    }

    /**
     * Returns the addresses that own a certain token.
     */
    function getOwners(uint256 id) public view returns (address[] memory) {
        return _owners[id];
    }

    /**
     * Returns the balance of a token for an account.
     */
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: Balance query for 0 address");
        return _balances[id][account];
    }

    /**
     * Returns batch of the balance of a token for an account.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: Arrays length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * Sets approval over the contract for an operator.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        require(_msgSender() != operator, "ERC1155: Setting approval for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * Returns whether an operator has approval for a certain account.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * Transfers an amount of tokens from one address to another address.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: Caller not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * Transfers amounts of different tokens from one address to another address.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: Caller not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * Destroys an amount of tokens from an account.
     */
    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) public {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: Caller not owner nor approved"
        );
        require(account != address(0), "ERC1155: Burn from 0 address");

        address operator = _msgSender();

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: Burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }
        _updateOwners(id, account, address(0), accountBalance, 0);

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * Destroys amounts of different tokens from an account.
     */
    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: Caller not owner nor approved"
        );
        require(account != address(0), "ERC1155: Burn from 0 address");
        require(ids.length == amounts.length, "ERC1155: Arrays length mismatch");

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: Burn amount exceeds balance");
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
            _updateOwners(id, account, address(0), accountBalance, 0);
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * Returns whether or not the contract supports a certain interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165, ERC1155Receiver, NftRoyalties)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * Wraps ERC721 token from a different contract.
     */
    function wrapERC721(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_
    ) external override returns (uint256) {
        require(
            IERC165(extNftContract).supportsInterface(type(IERC721).interfaceId),
            "ERC1155: Contract is not ERC721"
        );
        require(
            IERC165(extNftContract).supportsInterface(type(IERC721Metadata).interfaceId),
            "ERC1155: No metadata standard"
        );
        require(
            IERC721(extNftContract).ownerOf(extTokenId) == msg.sender,
            "ERC1155: Sender is not token owner"
        );

        IERC721(extNftContract).safeTransferFrom(msg.sender, address(this), extTokenId);

        uint256 tokenId = _extTokenIdToTokenId[extNftContract][extTokenId];
        if (tokenId > 0) {
            // Update amount for existing wrapped token
            _increaseSupply(tokenId, 1);
        } else {
            // Create new wrapped token
            address royaltyRecipient;
            uint256 royaltyValue;
            if (IERC165(extNftContract).supportsInterface(type(INftRoyalties).interfaceId)) {
                (royaltyRecipient, royaltyValue) = INftRoyalties(extNftContract).royaltyInfo(
                    extTokenId,
                    10000
                );
            }
            string memory uri_ = IERC721Metadata(extNftContract).tokenURI(extTokenId);
            tokenId = mint(msg.sender, 1, uri_, mimeType_, royaltyRecipient, royaltyValue);

            _wrappedTokens[tokenId] = WrappedToken(tokenId, true, extTokenId, extNftContract);
            _extTokenIdToTokenId[extNftContract][extTokenId] = tokenId;
        }

        emit WrapToken(tokenId, true, extTokenId, extNftContract, 1, true);

        return tokenId;
    }

    /**
     * Unwraps ERC721 token previously wrapped.
     */
    function unwrapERC721(uint256 tokenId) external override {
        require(balanceOf(msg.sender, tokenId) == 1, "ERC1155: Not token owned to unwrap");
        WrappedToken memory wrappedToken = getWrappedToken(tokenId);
        require(wrappedToken.isErc721, "ERC1155: Token is not ERC721");

        burn(msg.sender, tokenId, 1);

        IERC721(wrappedToken.extNftContract).safeTransferFrom(
            address(this),
            msg.sender,
            wrappedToken.extTokenId
        );

        emit WrapToken(
            tokenId,
            true,
            wrappedToken.extTokenId,
            wrappedToken.extNftContract,
            1,
            false
        );
    }

    /**
     * Wraps ERC1155 token from a different contract.
     */
    function wrapERC1155(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_,
        uint256 amount
    ) external override returns (uint256) {
        require(
            IERC165(extNftContract).supportsInterface(type(IERC1155).interfaceId),
            "ERC1155: Contract is not ERC1155"
        );
        require(
            IERC165(extNftContract).supportsInterface(type(IERC1155MetadataURI).interfaceId),
            "ERC1155: No metadata standard"
        );
        require(
            IERC1155(extNftContract).balanceOf(msg.sender, extTokenId) >= amount,
            "ERC1155: Not enough tokens owned"
        );

        IERC1155(extNftContract).safeTransferFrom(
            msg.sender,
            address(this),
            extTokenId,
            amount,
            ""
        );

        uint256 tokenId = _extTokenIdToTokenId[extNftContract][extTokenId];
        if (tokenId > 0) {
            // Update amount for existing wrapped token
            _increaseSupply(tokenId, amount);
        } else {
            // Create new wrapped token
            address royaltyRecipient;
            uint256 royaltyValue;
            if (IERC1155(extNftContract).supportsInterface(type(INftRoyalties).interfaceId)) {
                (royaltyRecipient, royaltyValue) = INftRoyalties(extNftContract).royaltyInfo(
                    extTokenId,
                    10000
                );
            }
            string memory uri_ = IERC1155MetadataURI(extNftContract).uri(extTokenId);
            tokenId = mint(msg.sender, amount, uri_, mimeType_, royaltyRecipient, royaltyValue);

            _wrappedTokens[tokenId] = WrappedToken(tokenId, false, extTokenId, extNftContract);
            _extTokenIdToTokenId[extNftContract][extTokenId] = tokenId;
        }

        emit WrapToken(tokenId, false, extTokenId, extNftContract, amount, true);

        return tokenId;
    }

    /**
     * Unwraps ERC1155 token previously wrapped.
     */
    function unwrapERC1155(uint256 tokenId) external override {
        uint256 balance = balanceOf(msg.sender, tokenId);
        require(balance > 0, "ERC1155: Not enough tokens owner");
        WrappedToken memory wrappedToken = getWrappedToken(tokenId);
        require(!wrappedToken.isErc721, "ERC1155: Token is not ERC1155");

        burn(msg.sender, wrappedToken.tokenId, balance);

        IERC1155(wrappedToken.extNftContract).safeTransferFrom(
            address(this),
            msg.sender,
            wrappedToken.extTokenId,
            balance,
            ""
        );

        emit WrapToken(
            tokenId,
            false,
            wrappedToken.extTokenId,
            wrappedToken.extNftContract,
            balance,
            false
        );
    }

    /**
     * Updates the owners of a token
     */
    function _updateOwners(
        uint256 id,
        address from,
        address to,
        uint256 fromInitialBalance,
        uint256 toInitialBalance
    ) internal {
        uint256 ownersLength = _owners[id].length;

        if (_balances[id][from] == 0 && from != address(0) && fromInitialBalance > 0) {
            for (uint256 i; i < ownersLength; ++i) {
                if (_owners[id][i] == from) {
                    _owners[id][i] = _owners[id][ownersLength - 1];
                    _owners[id].pop();
                    break;
                }
            }
        }

        if (_balances[id][to] > 0 && to != address(0) && toInitialBalance == 0) {
            _owners[id].push(to);
        }
    }

    /**
     * Transfers an amount of tokens from one address to another address.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: Transfer to 0 address");

        address operator = _msgSender();

        uint256 fromBalance = _balances[id][from];
        uint256 toBalance = _balances[id][to];
        require(fromBalance >= amount, "ERC1155: Insufficient token balance");

        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        _updateOwners(id, from, to, fromBalance, toBalance);

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * Transfers amounts of differnt tokens from one address to another address.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(ids.length == amounts.length, "ERC1155: Arrays length mismatch");
        require(to != address(0), "ERC1155: Transfer to 0 address");

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            uint256 toBalance = _balances[id][to];
            require(fromBalance >= amount, "ERC1155: Insufficient token balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
            _updateOwners(id, from, to, fromBalance, toBalance);
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * Checks if a token transfer has been accepted.
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: Transfer to non ERC1155Receiver");
            }
        }
    }

    /**
     * Checks if a batch token transfer has been accepted.
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data)
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: Transfer to non ERC1155Receiver");
            }
        }
    }

    /**
     * Increases amount of total supply for wrapped ERC1155 token.
     */
    function _increaseSupply(uint256 tokenId, uint256 amount)
        internal
        override
        wrappedExists(tokenId)
    {
        require(
            !_wrappedTokens[tokenId].isErc721 || getTokenSupply(tokenId) == 0,
            "ERC1155: ERC721 cannot increase supply"
        );

        address to = _msgSender();

        uint256 toBalance = _balances[tokenId][to];
        _balances[tokenId][to] += amount;

        _updateOwners(tokenId, address(0), to, 0, toBalance);
        emit TransferSingle(to, address(0), to, tokenId, amount);

        _doSafeTransferAcceptanceCheck(to, address(0), to, tokenId, amount, "");
    }
}
