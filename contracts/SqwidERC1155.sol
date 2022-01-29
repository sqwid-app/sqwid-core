//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/Address.sol";
import "../@openzeppelin/contracts/utils/Context.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "./NftRoyalties.sol";

contract SqwidERC1155 is Context, ERC165, IERC1155, NftRoyalties, Ownable {
    using Counters for Counters.Counter;
    using Address for address;

    // bytes4(keccak256("hasMutableURI(uint256))")) == 0xc962d178
    bytes4 private constant _INTERFACE_ID_MUTABLE_URI = 0xc962d178;

    Counters.Counter private _tokenIds;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(uint256 => address[]) private _owners;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _uris;
    mapping(bytes4 => bool) private _supportedInterfaces;
    mapping(uint256 => bool) private _mutableMetadataMapping;

    /**
     * Mints a new token.
     */
    function mint(
        address to,
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata
    ) public returns (uint256) {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(amount > 0, "ERC1155: amount has to be larger than zero");
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            address(0),
            to,
            _asSingletonArray(tokenId),
            _asSingletonArray(amount),
            ""
        );

        _balances[tokenId][to] += amount;
        _updateOwners(tokenId, address(0), to, 0, 0);
        emit TransferSingle(operator, address(0), to, tokenId, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, tokenId, amount, "");

        _uris[tokenId] = tokenURI;

        if (royaltyValue > 0) {
            _setTokenRoyalty(tokenId, royaltyRecipient, royaltyValue);
        }
        _mutableMetadataMapping[tokenId] = mutableMetadata;

        return tokenId;
    }

    /**
     * Mints new tokens in batch.
     */
    function mintBatch(
        address to,
        uint256[] memory amounts,
        string[] memory tokenURIs,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues,
        bool[] memory mutableMetadatas
    ) public returns (uint256[] memory) {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
            amounts.length == royaltyRecipients.length &&
                amounts.length == tokenURIs.length &&
                amounts.length == royaltyValues.length &&
                amounts.length == mutableMetadatas.length,
            "ERC1155: Arrays length mismatch"
        );

        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            _tokenIds.increment();
            ids[i] = _tokenIds.current();
        }

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, "");

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
            _mutableMetadataMapping[ids[i]] = mutableMetadatas[i];
            _uris[ids[i]] = tokenURIs[i];
        }

        return ids;
    }

    /**
     * Returns whether or not a token has mutable URI.
     */
    function hasMutableURI(uint256 tokenId) public view returns (bool mutableMetadata) {
        return _mutableMetadataMapping[tokenId];
    }

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
    function uri(uint256 tokenId) public view virtual returns (string memory) {
        return _uris[tokenId];
    }

    /**
     * Sets URI for a specific token.
     * Only allowed if sender is owner of total supply and NFT is mutable.
     */
    function setTokenUri(uint256 tokenId, string memory uriValue) public {
        require(
            balanceOf(msg.sender, tokenId) == getTokenSupply(tokenId),
            "SqwidERC1155: Only the owner of the total supply can set token URI."
        );
        require(
            _mutableMetadataMapping[tokenId],
            "SqwidERC1155: The metadata of this token is immutable."
        );

        _uris[tokenId] = uriValue;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    function getOwners(uint256 id) public view virtual returns (address[] memory) {
        return _owners[id];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            account,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 accountBalance = _balances[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }
        _updateOwners(id, account, address(0), accountBalance, 0);

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
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
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_ERC2981 ||
            interfaceId == _INTERFACE_ID_MUTABLE_URI ||
            super.supportsInterface(interfaceId);
    }

    ///////////////////////// INTERNAL FUNCTIONS //////////////////////////////

    /**
     * @dev Updates the owners of token `id`
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
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received}
     * and return the acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        uint256 fromBalance = _balances[id][from];
        uint256 toBalance = _balances[id][to];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");

        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        _updateOwners(id, from, to, fromBalance, toBalance);

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC1155Receiver-onERC1155BatchReceived} and return the acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            uint256 toBalance = _balances[id][to];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:
     * extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

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
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

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
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
