// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ISqwidERC1155.sol";

contract SqwidMarketplace is ERC1155Holder, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    enum PositionState {
        Available,
        RegularSale,
        Auction,
        Raffle,
        Loan
    }

    /**
     * Represents a specific token in the marketplace.
     */
    struct Item {
        uint256 itemId; // Incremental ID in the market contract
        address nftContract;
        uint256 tokenId; // Incremental ID in the NFT contract
        address creator;
        uint256 positionCount;
        ItemSale[] sales;
    }

    /**
     * Represents the position of a certain amount of tokens for an owner.
     * E.g.:
     *      - Alice has 10 XYZ tokens in auction
     *      - Alice has 2 XYZ tokens for sale for 5 Reef
     *      - Alice has 1 ABC token in a raffle
     *      - Bob has 10 XYZ tokens in sale for 5 Reef
     */
    struct Position {
        uint256 positionId;
        uint256 itemId;
        address payable owner;
        uint256 amount;
        uint256 price;
        uint256 marketFee; // Market fee at the moment of creating the item
        PositionState state;
    }

    struct ItemSale {
        address seller;
        address buyer;
        uint256 price;
        uint256 amount;
    }

    struct AuctionData {
        uint256 deadline;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
    }

    struct RaffleData {
        uint256 deadline;
        uint256 totalValue;
        mapping(address => uint256) addressToAmount;
        mapping(uint256 => address) indexToAddress;
        uint256 totalAddresses;
    }

    struct LoanData {
        uint256 loanAmount;
        uint256 feeAmount;
        uint256 numMinutes;
        uint256 deadline;
        address lender;
    }

    struct ItemResponse {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address creator;
        ItemSale[] sales;
        Position[] positions;
    }

    struct PositionResponse {
        uint256 positionId;
        Item item;
        address payable owner;
        uint256 amount;
        uint256 price;
        uint256 marketFee;
        PositionState state;
        AuctionData auctionData;
        RaffleDataResponse raffleData;
        LoanData loanData;
    }

    struct RaffleDataResponse {
        uint256 deadline;
        uint256 totalValue;
        uint256 totalAddresses;
    }

    // bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    Counters.Counter private _itemIds;
    Counters.Counter private _positionIds;
    Counters.Counter private _availablePositions;
    Counters.Counter private _onRegularSale;
    Counters.Counter private _onAuction;
    Counters.Counter private _onRaffle;
    Counters.Counter private _onLoan;
    uint256 public marketFee;
    address public nftContractAddress;

    mapping(uint256 => Item) private _idToItem;
    mapping(uint256 => Position) private _idToPosition;
    mapping(uint256 => AuctionData) private _idToAuctionData;
    mapping(uint256 => RaffleData) private _idToRaffleData;
    mapping(uint256 => LoanData) private _idToLoanData;
    mapping(address => uint256) public addressBalance;

    event ItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address creator
    );

    event PositionUpdate(
        uint256 indexed positionId,
        uint256 indexed itemId,
        address indexed owner,
        uint256 amount,
        uint256 price,
        uint256 marketFee,
        PositionState state
    );

    event PositionDelete(uint256 indexed positionId);

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 amount
    );

    event MarketFeeChanged(uint256 prevValue, uint256 newValue);

    event RoyaltiesPaid(uint256 indexed tokenId, uint256 value);

    modifier itemExists(uint256 itemId) {
        require(_idToItem[itemId].itemId > 0, "SqwidMarketplace: Item not found.");
        _;
    }

    modifier positionExists(uint256 positionId) {
        require(_idToPosition[positionId].positionId > 0, "SqwidMarketplace: Position not found.");
        _;
    }

    modifier positionInState(uint256 positionId, PositionState expectedState) {
        require(_idToPosition[positionId].positionId > 0, "SqwidMarketplace: Position not found.");
        require(
            _idToPosition[positionId].state == expectedState,
            "SqwidMarketplace: Position is not on required state."
        );
        _;
    }

    constructor(uint256 marketFee_, address nftContractAddress_) {
        marketFee = marketFee_;
        nftContractAddress = nftContractAddress_;
    }

    /**
     * Sets market fee percentage with two decimal points.
     * E.g. 250 --> 2.5%
     */
    function setMarketFee(uint256 marketFee_) external onlyOwner {
        require(
            marketFee_ <= 1000,
            "SqwidMarketplace: Market fee value cannot be higher than 1000."
        );
        uint256 prevMarketFee = marketFee;
        marketFee = marketFee_;
        emit MarketFeeChanged(prevMarketFee, marketFee_);
    }

    /**
     * Sets new NFT contract address.
     */
    function setNftContractAddress(address nftContractAddress_) external onlyOwner {
        require(nftContractAddress_ != address(0), "SqwidMarketplace: Cannot set to 0 address.");
        nftContractAddress = nftContractAddress_;
    }

    /**
     * Withdraws available balance from sender.
     */
    function withdraw() external {
        uint256 amount = addressBalance[msg.sender];
        addressBalance[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /**
     * Mints new SqwidERC1155 token and adds it to the marketplace.
     */
    function mint(
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata
    ) public returns (uint256) {
        uint256 tokenId = ISqwidERC1155(nftContractAddress).mint(
            msg.sender,
            amount,
            tokenURI,
            royaltyRecipient,
            royaltyValue,
            mutableMetadata
        );
        return createItem(nftContractAddress, tokenId);
    }

    /**
     * Mints batch of new SqwidERC1155 tokens and adds them to the marketplace.
     */
    function mintBatch(
        uint256[] memory amounts,
        string[] memory tokenURIs,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues,
        bool[] memory mutableMetadatas
    ) external {
        uint256[] memory tokenIds = ISqwidERC1155(nftContractAddress).mintBatch(
            msg.sender,
            amounts,
            tokenURIs,
            royaltyRecipients,
            royaltyValues,
            mutableMetadatas
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            createItem(nftContractAddress, tokenIds[i]);
        }
    }

    /**
     * Creates new market item.
     */
    function createItem(address nftContract, uint256 tokenId) public returns (uint256) {
        require(
            ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId) > 0,
            "SqwidMarketplace: This address does not own enough tokens."
        );

        // Check if item already exists
        uint256 totalItemCount = _itemIds.current();
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                _idToItem[i + 1].nftContract == nftContract && _idToItem[i + 1].tokenId == tokenId
            ) {
                revert("SqwidMarketplace: Item already exists.");
            }
        }

        // Map new Item
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        _idToItem[itemId].itemId = itemId;
        _idToItem[itemId].nftContract = nftContract;
        _idToItem[itemId].tokenId = tokenId;
        _idToItem[itemId].creator = msg.sender;
        _idToItem[itemId].positionCount = 0;

        _updateAvailablePosition(itemId, msg.sender);

        emit ItemCreated(itemId, nftContract, tokenId, msg.sender);

        return itemId;
    }

    /**
     * Returns item and all its item positions.
     */
    function fetchItem(uint256 itemId)
        public
        view
        itemExists(itemId)
        returns (ItemResponse memory)
    {
        return
            ItemResponse(
                itemId,
                _idToItem[itemId].nftContract,
                _idToItem[itemId].tokenId,
                _idToItem[itemId].creator,
                _idToItem[itemId].sales,
                _fetchPositionsByItemId(itemId)
            );
    }

    /**
     * Returns all items and all its item positions.
     */
    function fetchAllItems() public view returns (ItemResponse[] memory) {
        uint256 totalItemCount = _itemIds.current();

        // Initialize array
        ItemResponse[] memory items = new ItemResponse[](totalItemCount);

        // Fill array
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < totalItemCount; i++) {
            items[currentIndex] = fetchItem(i + 1);
            currentIndex += 1;
        }

        return items;
    }

    /**
     * Returns items created by caller.
     */
    function fetchMyItemsCreated() external view returns (ItemResponse[] memory) {
        return fetchAddressItemsCreated(msg.sender);
    }

    /**
     * Returns items created by an address.
     */
    function fetchAddressItemsCreated(address targetAddress)
        public
        view
        returns (ItemResponse[] memory)
    {
        // Get total number of items created by target address
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToItem[i + 1].creator == targetAddress) {
                itemCount += 1;
            }
        }

        // Initialize array
        ItemResponse[] memory items = new ItemResponse[](itemCount);

        // Fill array
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToItem[i + 1].creator == targetAddress) {
                items[currentIndex] = fetchItem(i + 1);
                currentIndex += 1;
            }
        }

        return items;
    }

    /**
     * Returns item position.
     */
    function fetchPosition(uint256 positionId)
        public
        view
        positionExists(positionId)
        returns (PositionResponse memory)
    {
        AuctionData memory auctionData;
        RaffleDataResponse memory raffleData;
        LoanData memory loanData;
        Item memory item = _idToItem[_idToPosition[positionId].itemId];
        uint256 amount = _idToPosition[positionId].amount;

        if (_idToPosition[positionId].state == PositionState.Available) {
            amount = ISqwidERC1155(item.nftContract).balanceOf(
                _idToPosition[positionId].owner,
                item.tokenId
            );
        } else if (_idToPosition[positionId].state == PositionState.Auction) {
            auctionData = _idToAuctionData[positionId];
        } else if (_idToPosition[positionId].state == PositionState.Raffle) {
            raffleData.deadline = _idToRaffleData[positionId].deadline;
            raffleData.totalValue = _idToRaffleData[positionId].totalValue;
            raffleData.totalAddresses = _idToRaffleData[positionId].totalAddresses;
        } else if (_idToPosition[positionId].state == PositionState.Loan) {
            loanData = _idToLoanData[positionId];
        }

        return
            PositionResponse(
                positionId,
                item,
                _idToPosition[positionId].owner,
                amount,
                _idToPosition[positionId].price,
                _idToPosition[positionId].marketFee,
                _idToPosition[positionId].state,
                auctionData,
                raffleData,
                loanData
            );
    }

    /**
     * Returns item positions from caller.
     */
    function fetchMyPositions() external view returns (PositionResponse[] memory) {
        return fetchAddressPositions(msg.sender);
    }

    /**
     * Returns items positions from an address.
     */
    function fetchAddressPositions(address targetAddress)
        public
        view
        returns (PositionResponse[] memory)
    {
        // Get total number of items on sale by target address
        uint256 totalPositionCount = _positionIds.current();
        uint256 positionCount = 0;
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].owner == targetAddress) {
                positionCount += 1;
            }
        }

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](positionCount);

        // Fill array
        for (uint256 i = 0; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].owner == targetAddress) {
                positions[currentIndex] = fetchPosition(i + 1);
                currentIndex += 1;
            }
        }

        return positions;
    }

    /////////////////////////// AVAILABLE ////////////////////////////////////

    /**
     * Registers in the marketplace the ownership of an existing item.
     */
    function addAvailableTokens(uint256 itemId) public itemExists(itemId) {
        require(
            ISqwidERC1155(_idToItem[itemId].nftContract).balanceOf(
                msg.sender,
                _idToItem[itemId].tokenId
            ) > 0,
            "SqwidMarketplace: This address does not own enough tokens."
        );
        Position memory position = _fetchAvalailablePosition(itemId, msg.sender);
        if (position.itemId != 0) {
            revert("SqwidMarketplace: Item already registered by this user.");
        }
        _updateAvailablePosition(itemId, msg.sender);
    }

    /**
     * Returns market item positions available (not on sale, auction, raffle or loan).
     */
    function fetchAllAvailablePositions() external view returns (PositionResponse[] memory) {
        return _fetchPositionsByState(PositionState.Available);
    }

    /////////////////////////// REGULAR SALE ////////////////////////////////////

    /**
     * Puts on sale a new market item.
     */
    function putNewItemOnSale(
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata,
        uint256 price
    ) external {
        // Mint and create market item
        uint256 itemId = mint(amount, tokenURI, royaltyRecipient, royaltyValue, mutableMetadata);

        // Put on sale
        putItemOnSale(itemId, amount, price);
    }

    /**
     * Puts on sale existing market item.
     */
    function putItemOnSale(
        uint256 itemId,
        uint256 amount,
        uint256 price
    ) public itemExists(itemId) {
        require(price > 0, "SqwidMarketplace: Price must be greater than 0.");
        require(amount > 0, "SqwidMarketplace: Amount must be greater than 0.");
        require(
            amount <=
                ISqwidERC1155(_idToItem[itemId].nftContract).balanceOf(
                    msg.sender,
                    _idToItem[itemId].tokenId
                ),
            "SqwidMarketplace: Available NFT balance is not enough."
        );

        // Transfer ownership of the token to this contract
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            _idToItem[itemId].tokenId,
            amount,
            ""
        );

        // Map new Position
        _positionIds.increment();
        uint256 positionId = _positionIds.current();
        _idToPosition[positionId] = Position(
            positionId,
            itemId,
            payable(msg.sender),
            amount,
            price,
            marketFee,
            PositionState.RegularSale
        );

        _idToItem[itemId].positionCount++;

        _onRegularSale.increment();

        emit PositionUpdate(
            positionId,
            itemId,
            msg.sender,
            amount,
            price,
            marketFee,
            PositionState.RegularSale
        );
    }

    /**
     * Creates a new sale for a existing market item.
     */
    function createSale(uint256 positionId, uint256 amount)
        external
        payable
        positionInState(positionId, PositionState.RegularSale)
        nonReentrant
    {
        require(
            _idToPosition[positionId].amount >= amount,
            "SqwidMarketplace: The amount sent is greater than the amount available."
        );
        uint256 price = _idToPosition[positionId].price;
        require(
            msg.value == (price * amount),
            "SqwidMarketplace: Value of transaction must be equal to sale price * amount."
        );

        uint256 itemId = _idToPosition[positionId].itemId;
        address seller = _idToPosition[positionId].owner;

        // Process transaction
        _createItemTransaction(positionId, msg.sender, msg.value, amount);

        // Update item and item position
        _idToItem[itemId].sales.push(ItemSale(seller, msg.sender, msg.value, amount));
        if (amount == _idToPosition[positionId].amount) {
            // Sale ended
            delete _idToPosition[positionId];
            emit PositionDelete(positionId);
            _idToItem[itemId].positionCount--;
            _onRegularSale.decrement();
        } else {
            // Partial sale
            _idToPosition[positionId].amount -= amount;
        }

        emit MarketItemSold(
            itemId,
            _idToItem[itemId].nftContract,
            _idToItem[itemId].tokenId,
            seller,
            msg.sender,
            msg.value,
            amount
        );

        _updateAvailablePosition(itemId, msg.sender);
    }

    /**
     * Unlist item from regular sale.
     */
    function unlistPositionOnSale(uint256 positionId)
        external
        positionInState(positionId, PositionState.RegularSale)
    {
        require(
            msg.sender == _idToPosition[positionId].owner,
            "SqwidMarketplace: Only seller can unlist item."
        );

        uint256 itemId = _idToPosition[positionId].itemId;

        // Transfer ownership back to seller
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            _idToItem[itemId].tokenId,
            _idToPosition[positionId].amount,
            ""
        );

        // Delete item position
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onRegularSale.decrement();

        _updateAvailablePosition(itemId, msg.sender);
    }

    /**
     * Returns market item positions on regular sale.
     */
    function fetchAllOnRegularSale() external view returns (PositionResponse[] memory) {
        return _fetchPositionsByState(PositionState.RegularSale);
    }

    /////////////////////////// AUCTION ////////////////////////////////////

    /**
     * Creates an auction for a new market item.
     */
    function createNewItemAuction(
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata,
        uint256 numMinutes,
        uint256 minBid
    ) external {
        // Mint and create market item
        uint256 itemId = mint(amount, tokenURI, royaltyRecipient, royaltyValue, mutableMetadata);

        // Create auction
        createItemAuction(itemId, amount, numMinutes, minBid);
    }

    /**
     * Creates an auction from an existing market item.
     */
    function createItemAuction(
        uint256 itemId,
        uint256 amount,
        uint256 numMinutes,
        uint256 minBid
    ) public itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            amount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarketplace: Available NFT balance is not enough."
        );
        require(amount > 0, "SqwidMarketplace: Amount must be greater than 0.");
        require(
            numMinutes >= 1 && numMinutes <= 44640,
            "SqwidMarketplace: Number of minutes must be between 0 and 44,640."
        ); // 44,640 min = 1 month
        // TODO change min numMinutes to 60 ?

        // Transfer ownership of the token to this contract
        ISqwidERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        // Map new Position
        _positionIds.increment();
        uint256 positionId = _positionIds.current();
        _idToPosition[positionId] = Position(
            positionId,
            itemId,
            payable(msg.sender),
            amount,
            0,
            marketFee,
            PositionState.Auction
        );

        _idToItem[itemId].positionCount++;

        // Create AuctionData
        uint256 deadline = (block.timestamp + numMinutes * 1 minutes);
        _idToAuctionData[positionId].deadline = deadline;
        _idToAuctionData[positionId].minBid = minBid;
        _idToAuctionData[positionId].highestBidder = address(0);
        _idToAuctionData[positionId].highestBid = 0;

        _onAuction.increment();

        emit PositionUpdate(
            positionId,
            itemId,
            msg.sender,
            amount,
            0,
            marketFee,
            PositionState.Auction
        );
    }

    /**
     * Adds bid to an active auction.
     */
    function createBid(uint256 positionId)
        external
        payable
        positionInState(positionId, PositionState.Auction)
        nonReentrant
    {
        address highestBidder = _idToAuctionData[positionId].highestBidder;
        uint256 highestBid = _idToAuctionData[positionId].highestBid;
        require(
            _idToAuctionData[positionId].deadline >= block.timestamp,
            "SqwidMarketplace: Auction has ended."
        );
        require(
            msg.value >= _idToAuctionData[positionId].minBid || msg.sender == highestBidder,
            "SqwidMarketplace: Bid value cannot be lower than minimum bid."
        );
        require(
            msg.value > highestBid || msg.sender == highestBidder,
            "SqwidMarketplace: Bid value cannot be lower than highest bid."
        );

        // Update AuctionData
        if (msg.sender == highestBidder) {
            // Highest bidder increases bid value
            _idToAuctionData[positionId].highestBid += msg.value;
        } else {
            if (highestBidder != address(0)) {
                // Return bid amount to previous highest bidder, if exists
                if (!payable(highestBidder).send(highestBid)) {
                    addressBalance[highestBidder] += highestBid;
                }
            }
            _idToAuctionData[positionId].highestBid = msg.value;
            _idToAuctionData[positionId].highestBidder = msg.sender;
        }

        // Extend deadline if we are on last 10 minutes
        uint256 secsToDeadline = _idToAuctionData[positionId].deadline - block.timestamp;
        if (secsToDeadline < 600) {
            _idToAuctionData[positionId].deadline += (600 - secsToDeadline);
        }
    }

    /**
     * Distributes NFTs and bidded amount after auction deadline is reached.
     */
    function endAuction(uint256 positionId)
        external
        positionInState(positionId, PositionState.Auction)
        nonReentrant
    {
        require(
            _idToAuctionData[positionId].deadline < block.timestamp,
            "SqwidMarketplace: Auction deadline has not been reached yet."
        );

        uint256 itemId = _idToPosition[positionId].itemId;
        address seller = _idToPosition[positionId].owner;
        address receiver;
        uint256 amount = _idToPosition[positionId].amount;

        // Check if there are bids
        if (_idToAuctionData[positionId].highestBid > 0) {
            receiver = _idToAuctionData[positionId].highestBidder;
            // Create transaction
            _createItemTransaction(
                positionId,
                receiver,
                _idToAuctionData[positionId].highestBid,
                amount
            );
            // Add sale to item
            _idToItem[itemId].sales.push(
                ItemSale(seller, receiver, _idToAuctionData[positionId].highestBid, amount)
            );
            emit MarketItemSold(
                itemId,
                _idToItem[itemId].nftContract,
                _idToItem[itemId].tokenId,
                seller,
                receiver,
                _idToAuctionData[positionId].highestBid,
                amount
            );
        } else {
            receiver = seller;
            // Transfer ownership of the token back to seller
            ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
                address(this),
                seller,
                _idToItem[itemId].tokenId,
                amount,
                ""
            );
        }

        // Delete position and auction data
        delete _idToAuctionData[positionId];
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onAuction.decrement();

        _updateAvailablePosition(itemId, receiver);
    }

    /**
     * Returns active auctions.
     */
    function fetchAllAuctions() external view returns (PositionResponse[] memory) {
        return _fetchPositionsByState(PositionState.Auction);
    }

    /////////////////////////// RAFFLE ////////////////////////////////////

    /**
     * Creates a raffle for a new market item.
     */
    function createNewItemRaffle(
        uint256 amount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata,
        uint256 numMinutes
    ) external {
        // Mint and create market item
        uint256 itemId = mint(amount, tokenURI, royaltyRecipient, royaltyValue, mutableMetadata);

        // Create raffle
        createItemRaffle(itemId, amount, numMinutes);
    }

    /**
     * Creates a raffle from an existing market item.
     */
    function createItemRaffle(
        uint256 itemId,
        uint256 amount,
        uint256 numMinutes
    ) public itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            amount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarketplace: Available NFT balance is not enough."
        );
        require(amount > 0, "SqwidMarketplace: Amount must be greater than 0.");
        require(
            numMinutes >= 1 && numMinutes <= 44640,
            "SqwidMarketplace: Number of minutes must be between 0 and 44,640."
        ); // 44,640 min = 1 month
        // TODO change min numMinutes to 60 ?

        // Transfer ownership of the token to this contract
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );

        // Map new Position
        _positionIds.increment();
        uint256 positionId = _positionIds.current();
        _idToPosition[positionId] = Position(
            positionId,
            itemId,
            payable(msg.sender),
            amount,
            0,
            marketFee,
            PositionState.Raffle
        );

        _idToItem[itemId].positionCount++;

        // Create RaffleData
        uint256 deadline = (block.timestamp + numMinutes * 1 minutes);
        _idToRaffleData[positionId].deadline = deadline;

        _onRaffle.increment();

        emit PositionUpdate(
            positionId,
            itemId,
            msg.sender,
            amount,
            0,
            marketFee,
            PositionState.Raffle
        );
    }

    /**
     * Adds entry to an active raffle.
     */
    function enterRaffle(uint256 positionId)
        external
        payable
        positionInState(positionId, PositionState.Raffle)
    {
        require(
            _idToRaffleData[positionId].deadline >= block.timestamp,
            "SqwidMarketplace: Raffle has ended."
        );
        require(
            msg.value >= 1 * (10**18),
            "SqwidMarketplace: Value of transaction must be at least 1 REEF."
        );

        uint256 value = msg.value / (10**18);

        // Update RaffleData
        if (!(_idToRaffleData[positionId].addressToAmount[msg.sender] > 0)) {
            _idToRaffleData[positionId].indexToAddress[
                _idToRaffleData[positionId].totalAddresses
            ] = payable(msg.sender);
            _idToRaffleData[positionId].totalAddresses += 1;
        }
        _idToRaffleData[positionId].addressToAmount[msg.sender] += value;
        _idToRaffleData[positionId].totalValue += value;
    }

    /**
     * Ends open raffle.
     */
    function endRaffle(uint256 positionId)
        external
        positionInState(positionId, PositionState.Raffle)
        nonReentrant
    {
        require(
            _idToRaffleData[positionId].deadline < block.timestamp,
            "SqwidMarketplace: Raffle deadline has not been reached yet."
        );

        uint256 itemId = _idToPosition[positionId].itemId;
        address seller = _idToPosition[positionId].owner;
        address receiver;
        uint256 amount = _idToPosition[positionId].amount;

        // Check if there are participants in the raffle
        uint256 totalAddresses = _idToRaffleData[positionId].totalAddresses;
        if (totalAddresses > 0) {
            // Choose winner for the raffle
            uint256 totalValue = _idToRaffleData[positionId].totalValue;
            uint256 indexWinner = _pseudoRand() % totalValue;
            uint256 lastIndex = 0;
            for (uint256 i = 0; i < totalAddresses; i++) {
                address currAddress = _idToRaffleData[positionId].indexToAddress[i];
                lastIndex += _idToRaffleData[positionId].addressToAmount[currAddress];
                if (indexWinner < lastIndex) {
                    receiver = currAddress;
                    // Create transaction to winner
                    _createItemTransaction(positionId, receiver, totalValue * (10**18), amount);
                    // Add sale to item
                    _idToItem[itemId].sales.push(
                        ItemSale(seller, receiver, totalValue * (10**18), amount)
                    );
                    emit MarketItemSold(
                        itemId,
                        _idToItem[itemId].nftContract,
                        _idToItem[itemId].tokenId,
                        seller,
                        receiver,
                        totalValue,
                        amount
                    );
                    break;
                }
            }
        } else {
            receiver = seller;
            // Transfer ownership back to seller
            ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
                address(this),
                receiver,
                _idToItem[itemId].tokenId,
                amount,
                ""
            );
        }

        // Delete position and raffle data
        delete _idToRaffleData[positionId];
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onRaffle.decrement();

        _updateAvailablePosition(itemId, receiver);
    }

    /**
     * Returns all active raffles.
     */
    function fetchAllRaffles() external view returns (PositionResponse[] memory) {
        return _fetchPositionsByState(PositionState.Raffle);
    }

    /////////////////////////// LOAN ////////////////////////////////////

    /**
     * Creates a loan for a new market item.
     */
    function createNewItemLoan(
        uint256 tokenAmount,
        string memory tokenURI,
        address royaltyRecipient,
        uint256 royaltyValue,
        bool mutableMetadata,
        uint256 loanAmount,
        uint256 feeAmount,
        uint256 numMinutes
    ) external {
        // Mint and create market item
        uint256 itemId = mint(
            tokenAmount,
            tokenURI,
            royaltyRecipient,
            royaltyValue,
            mutableMetadata
        );

        // Create raffle
        createItemLoan(itemId, loanAmount, feeAmount, tokenAmount, numMinutes);
    }

    /**
     * Creates a loan from an existing market item.
     */
    function createItemLoan(
        uint256 itemId,
        uint256 loanAmount,
        uint256 feeAmount,
        uint256 tokenAmount,
        uint256 numMinutes
    ) public itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            tokenAmount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarketplace: Available NFT balance is not enough."
        );
        require(loanAmount > 0, "SqwidMarketplace: Loan amount must be greater than 0.");
        require(feeAmount >= 0, "SqwidMarketplace: Fee amount cannot be lower than 0.");
        require(tokenAmount > 0, "SqwidMarketplace: Token amount must be greater than 0.");
        require(
            numMinutes >= 1 && numMinutes <= 2628000,
            "SqwidMarketplace: Number of minutes must be between 1,440 and 2,628,000."
        ); // 1,440 min = 1 day - 2,628,000 min = 5 years
        // TODO change min numMinutes to 1440

        // Transfer ownership of the token to this contract
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            tokenAmount,
            ""
        );

        // Map new Position
        _positionIds.increment();
        uint256 positionId = _positionIds.current();
        _idToPosition[positionId] = Position(
            positionId,
            itemId,
            payable(msg.sender),
            tokenAmount,
            0,
            marketFee,
            PositionState.Loan
        );

        _idToItem[itemId].positionCount++;

        // Create LoanData
        _idToLoanData[positionId].loanAmount = loanAmount;
        _idToLoanData[positionId].feeAmount = feeAmount;
        _idToLoanData[positionId].numMinutes = numMinutes;

        _onLoan.increment();

        emit PositionUpdate(
            positionId,
            itemId,
            msg.sender,
            tokenAmount,
            0,
            marketFee,
            PositionState.Loan
        );
    }

    /**
     * Lender funds a loan proposal.
     */
    function fundLoan(uint256 positionId)
        public
        payable
        positionInState(positionId, PositionState.Loan)
    {
        require(
            _idToLoanData[positionId].lender == address(0),
            "SqwidMarketplace: This loan has already been funded."
        );
        require(
            msg.value == _idToLoanData[positionId].loanAmount,
            "SqwidMarketplace: Value sent must be equal to loan amount."
        );

        // Update LoanData
        _idToLoanData[positionId].lender = msg.sender;
        _idToLoanData[positionId].deadline =
            block.timestamp +
            _idToLoanData[positionId].numMinutes *
            1 minutes;

        // Transfer funds to borrower
        payable(_idToPosition[positionId].owner).transfer(msg.value);
    }

    /**
     * Borrower repays loan.
     */
    function repayLoan(uint256 positionId)
        public
        payable
        positionInState(positionId, PositionState.Loan)
        nonReentrant
    {
        require(
            _idToLoanData[positionId].lender != address(0),
            "SqwidMarketplace: This loan has not been funded."
        );
        require(
            msg.value >= _idToLoanData[positionId].loanAmount + _idToLoanData[positionId].feeAmount,
            "SqwidMarketplace: Value sent is less than loan amount plus fee."
        );

        // Transfer funds to lender
        if (!payable(_idToLoanData[positionId].lender).send(msg.value)) {
            addressBalance[_idToLoanData[positionId].lender] += msg.value;
        }

        uint256 itemId = _idToPosition[positionId].itemId;
        uint256 amount = _idToPosition[positionId].amount;
        address borrower = _idToPosition[positionId].owner;

        // Transfer tokens back to borrower
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            address(this),
            borrower,
            _idToItem[itemId].tokenId,
            amount,
            ""
        );

        // Delete position and loan data
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onLoan.decrement();

        _updateAvailablePosition(itemId, borrower);
    }

    /**
     * Funder liquidates expired loan.
     */
    function liquidateLoan(uint256 positionId)
        public
        positionInState(positionId, PositionState.Loan)
    {
        require(
            msg.sender == _idToLoanData[positionId].lender,
            "SqwidMarketplace: Only lender can liquidate the loan."
        );
        require(
            _idToLoanData[positionId].deadline < block.timestamp,
            "SqwidMarketplace: The repayment deadline has not been reached yet."
        );

        uint256 itemId = _idToPosition[positionId].itemId;

        // Transfer tokens to lender
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            _idToItem[itemId].tokenId,
            _idToPosition[positionId].amount,
            ""
        );

        // Delete position and loan data
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onLoan.decrement();

        _updateAvailablePosition(itemId, msg.sender);
    }

    /**
     * Unlist loan proposal sale.
     */
    function unlistLoanProposal(uint256 positionId)
        external
        positionInState(positionId, PositionState.Loan)
        nonReentrant
    {
        require(
            msg.sender == _idToPosition[positionId].owner,
            "SqwidMarketplace: Only borrower can unlist loan."
        );
        require(
            _idToLoanData[positionId].lender == address(0),
            "SqwidMarketplace: Cannot unlist loan already funded."
        );

        uint256 itemId = _idToPosition[positionId].itemId;

        // Transfer tokens back to borrower
        ISqwidERC1155(_idToItem[itemId].nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            _idToItem[itemId].tokenId,
            _idToPosition[positionId].amount,
            ""
        );

        // Delete position and loan data
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _onLoan.decrement();

        _updateAvailablePosition(itemId, msg.sender);
    }

    /**
     * Returns market item positions on loan.
     */
    function fetchAllLoans() external view returns (PositionResponse[] memory) {
        return _fetchPositionsByState(PositionState.Loan);
    }

    /////////////////////////// UTILS ////////////////////////////////////

    /**
     * Pays royalties to the address designated by the NFT contract and returns the sale place
     * minus the royalties payed.
     */
    function _deduceRoyalties(
        address _nftContract,
        uint256 _tokenId,
        uint256 _grossSaleValue,
        address payable _seller
    ) private returns (uint256 netSaleAmount) {
        // Get amount of royalties to pay and recipient
        (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(_nftContract).royaltyInfo(
            _tokenId,
            _grossSaleValue
        );

        // If seller and royalties receiver are the same, royalties will not be deduced
        if (_seller == royaltiesReceiver) {
            return _grossSaleValue;
        }

        // Deduce royalties from sale value
        uint256 netSaleValue = _grossSaleValue - royaltiesAmount;

        // Transfer royalties to rightholder if amount is not 0
        if (royaltiesAmount > 0) {
            (bool successTx, ) = royaltiesReceiver.call{ value: royaltiesAmount }("");
            if (successTx) {
                emit RoyaltiesPaid(_tokenId, royaltiesAmount);
            } else {
                addressBalance[royaltiesReceiver] += royaltiesAmount;
            }
        }

        return netSaleValue;
    }

    /**
     * Gets a pseudo-random number
     */
    function _pseudoRand() private view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        block.difficulty +
                        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) /
                            (block.timestamp)) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
                        block.number
                )
            )
        );

        return seed;
    }

    /**
     * Creates transaction of token and selling amount
     */
    function _createItemTransaction(
        uint256 positionId,
        address tokenRecipient,
        uint256 saleValue,
        uint256 amount
    ) private {
        uint256 itemId = _idToPosition[positionId].itemId;
        // Pay royalties
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        address payable seller = _idToPosition[positionId].owner;
        if (_checkRoyalties(nftContract)) {
            saleValue = _deduceRoyalties(nftContract, tokenId, saleValue, seller);
        }

        // Allocate market fee into owner balance
        uint256 marketFeeAmount = (saleValue * _idToPosition[positionId].marketFee) / 10000;
        addressBalance[owner()] += marketFeeAmount;

        uint256 netSaleValue = saleValue - marketFeeAmount;

        // Transfer value of the transaction to the seller
        (bool successTx, ) = seller.call{ value: netSaleValue }("");
        if (!successTx) {
            addressBalance[seller] += netSaleValue;
        }

        // Transfer ownership of the token to buyer
        ISqwidERC1155(nftContract).safeTransferFrom(
            address(this),
            tokenRecipient,
            tokenId,
            amount,
            ""
        );
    }

    /**
     * Checks if a contract supports EIP-2981 for royalties.
     * View EIP-165 (https://eips.ethereum.org/EIPS/eip-165).
     */
    function _checkRoyalties(address contractAddress) private view returns (bool) {
        bool success = IERC165(contractAddress).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    /**
     * Creates new position or updates amount in exising one for receiver of tokens.
     */
    function _updateAvailablePosition(uint256 itemId, address tokenOwner) private {
        uint256 receiverPositionId;
        uint256 amount = ISqwidERC1155(_idToItem[itemId].nftContract).balanceOf(
            tokenOwner,
            _idToItem[itemId].tokenId
        );
        Position memory position = _fetchAvalailablePosition(itemId, tokenOwner);
        if (position.itemId != 0) {
            receiverPositionId = position.itemId;
            _idToPosition[receiverPositionId].amount = amount;
        } else {
            _positionIds.increment();
            receiverPositionId = _positionIds.current();
            _idToPosition[receiverPositionId] = Position(
                receiverPositionId,
                itemId,
                payable(tokenOwner),
                amount,
                0,
                0,
                PositionState.Available
            );

            _availablePositions.increment();
            _idToItem[itemId].positionCount++;
        }

        emit PositionUpdate(
            receiverPositionId,
            _idToPosition[receiverPositionId].itemId,
            _idToPosition[receiverPositionId].owner,
            _idToPosition[receiverPositionId].amount,
            _idToPosition[receiverPositionId].price,
            _idToPosition[receiverPositionId].marketFee,
            _idToPosition[receiverPositionId].state
        );
    }

    /**
     * Returns item positions of a certain item.
     */
    function _fetchPositionsByItemId(uint256 itemId) private view returns (Position[] memory) {
        // Initialize array
        Position[] memory items = new Position[](_idToItem[itemId].positionCount);

        // Fill array
        uint256 totalPositionCount = _positionIds.current();
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].itemId == itemId) {
                items[currentIndex] = _idToPosition[i + 1];
                currentIndex++;
            }
        }

        return items;
    }

    /**
     * Returns item available position of a certain item and owner.
     */
    function _fetchAvalailablePosition(uint256 itemId, address tokenOwner)
        private
        view
        returns (Position memory)
    {
        uint256 totalPositionCount = _positionIds.current();
        for (uint256 i = 0; i < totalPositionCount; i++) {
            if (
                _idToPosition[i + 1].itemId == itemId &&
                _idToPosition[i + 1].owner == tokenOwner &&
                _idToPosition[i + 1].state == PositionState.Available
            ) {
                return _idToPosition[i + 1];
            }
        }

        Position memory emptyPosition;
        return emptyPosition;
    }

    /**
     * Returns market item positions for a given state.
     */
    function _fetchPositionsByState(PositionState state)
        private
        view
        returns (PositionResponse[] memory)
    {
        uint256 currentIndex = 0;
        uint256 stateCount;
        if (state == PositionState.Available) {
            stateCount = _availablePositions.current();
        } else if (state == PositionState.RegularSale) {
            stateCount = _onRegularSale.current();
        } else if (state == PositionState.Auction) {
            stateCount = _onAuction.current();
        } else if (state == PositionState.Raffle) {
            stateCount = _onRaffle.current();
        } else if (state == PositionState.Loan) {
            stateCount = _onLoan.current();
        }

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](stateCount);

        // Fill array
        uint256 totalPositionCount = _positionIds.current();
        for (uint256 i = 0; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].positionId > 0 && _idToPosition[i + 1].state == state) {
                positions[currentIndex] = fetchPosition(i + 1);
                currentIndex += 1;
            }
        }

        return positions;
    }
}
