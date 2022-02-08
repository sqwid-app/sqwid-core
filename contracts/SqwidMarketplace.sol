// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ISqwidERC1155.sol";
import "./interface/INftRoyalties.sol";

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
        mapping(address => uint256) addressToAmount;
        mapping(uint256 => address) indexToAddress;
        uint256 totalAddresses;
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
        AuctionDataResponse auctionData;
        RaffleDataResponse raffleData;
        LoanData loanData;
    }

    struct AuctionDataResponse {
        uint256 deadline;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
    }

    struct RaffleDataResponse {
        uint256 deadline;
        uint256 totalValue;
        uint256 totalAddresses;
    }

    Counters.Counter private _itemIds;
    Counters.Counter private _positionIds;
    mapping(uint256 => Item) private _idToItem;
    mapping(uint256 => Position) private _idToPosition;
    mapping(PositionState => Counters.Counter) private _stateToCounter;
    mapping(uint256 => AuctionData) private _idToAuctionData;
    mapping(uint256 => RaffleData) private _idToRaffleData;
    mapping(uint256 => LoanData) private _idToLoanData;

    mapping(address => uint256) public addressBalance;
    uint256 public marketFee;
    address public nftContractAddress;

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
        require(_idToItem[itemId].itemId > 0, "SqwidMarket: Item not found");
        _;
    }

    modifier positionExists(uint256 positionId) {
        require(_idToPosition[positionId].positionId > 0, "SqwidMarket: Position not found");
        _;
    }

    modifier positionInState(uint256 positionId, PositionState expectedState) {
        require(_idToPosition[positionId].positionId > 0, "SqwidMarket: Position not found");
        require(
            _idToPosition[positionId].state == expectedState,
            "SqwidMarket: Position on wrong state"
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
        require(marketFee_ <= 1000, "SqwidMarket: Fee higher than 1000");
        uint256 prevMarketFee;
        prevMarketFee = marketFee;
        marketFee = marketFee_;

        emit MarketFeeChanged(prevMarketFee, marketFee_);
    }

    /**
     * Sets new NFT contract address.
     */
    function setNftContractAddress(address nftContractAddress_) external onlyOwner {
        require(nftContractAddress_ != address(0), "SqwidMarket: Cannot set to 0 address");
        nftContractAddress = nftContractAddress_;
    }

    /**
     * Withdraws available balance from sender.
     */
    function withdraw() external {
        uint256 amount = addressBalance[msg.sender];
        require(amount > 0, "SqwidMarket: No Reef to be claimed");
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
        uint256 royaltyValue
    ) external {
        uint256 tokenId = ISqwidERC1155(nftContractAddress).mint(
            msg.sender,
            amount,
            tokenURI,
            royaltyRecipient,
            royaltyValue
        );
        createItem(tokenId);
    }

    /**
     * Mints batch of new SqwidERC1155 tokens and adds them to the marketplace.
     */
    function mintBatch(
        uint256[] memory amounts,
        string[] memory tokenURIs,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues
    ) external {
        uint256[] memory tokenIds = ISqwidERC1155(nftContractAddress).mintBatch(
            msg.sender,
            amounts,
            tokenURIs,
            royaltyRecipients,
            royaltyValues
        );
        for (uint256 i; i < tokenIds.length; i++) {
            createItem(tokenIds[i]);
        }
    }

    /**
     * Creates new market item.
     */
    function createItem(uint256 tokenId) public returns (uint256) {
        require(
            ISqwidERC1155(nftContractAddress).balanceOf(msg.sender, tokenId) > 0,
            "SqwidMarket: Address balance too low"
        );

        // Check if item already exists
        uint256 totalItemCount = _itemIds.current();
        for (uint256 i; i < totalItemCount; i++) {
            if (
                _idToItem[i + 1].nftContract == nftContractAddress &&
                _idToItem[i + 1].tokenId == tokenId
            ) {
                revert("SqwidMarket: Item already exists");
            }
        }

        // Map new Item
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        _idToItem[itemId].itemId = itemId;
        _idToItem[itemId].nftContract = nftContractAddress;
        _idToItem[itemId].tokenId = tokenId;
        _idToItem[itemId].creator = msg.sender;
        _idToItem[itemId].positionCount = 0;

        _updateAvailablePosition(itemId, msg.sender);

        emit ItemCreated(itemId, nftContractAddress, tokenId, msg.sender);

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
        for (uint256 i; i < totalItemCount; i++) {
            items[currentIndex] = fetchItem(i + 1);
            currentIndex += 1;
        }

        return items;
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
        for (uint256 i; i < totalItemCount; i++) {
            if (_idToItem[i + 1].creator == targetAddress) {
                itemCount += 1;
            }
        }

        // Initialize array
        ItemResponse[] memory items = new ItemResponse[](itemCount);

        // Fill array
        uint256 currentIndex = 0;
        for (uint256 i; i < totalItemCount; i++) {
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
        AuctionDataResponse memory auctionData;
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
            auctionData.deadline = _idToAuctionData[positionId].deadline;
            auctionData.minBid = _idToAuctionData[positionId].minBid;
            auctionData.highestBidder = _idToAuctionData[positionId].highestBidder;
            auctionData.highestBid = _idToAuctionData[positionId].highestBid;
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
        for (uint256 i; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].owner == targetAddress) {
                positionCount += 1;
            }
        }

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](positionCount);

        // Fill array
        for (uint256 i; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].owner == targetAddress) {
                positions[currentIndex] = fetchPosition(i + 1);
                currentIndex += 1;
            }
        }

        return positions;
    }

    /**
     * Returns market item positions for a given state.
     */
    function fetchPositionsByState(PositionState state)
        external
        view
        returns (PositionResponse[] memory)
    {
        uint256 currentIndex = 0;
        uint256 stateCount = _stateToCounter[state].current();

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](stateCount);

        // Fill array
        uint256 totalPositionCount = _positionIds.current();
        for (uint256 i; i < totalPositionCount; i++) {
            if (_idToPosition[i + 1].positionId > 0 && _idToPosition[i + 1].state == state) {
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
            "SqwidMarket: Address balance too low"
        );
        Position memory position = _fetchAvalailablePosition(itemId, msg.sender);
        if (position.itemId != 0) {
            revert("SqwidMarket: Item already registered");
        }
        _updateAvailablePosition(itemId, msg.sender);
    }

    /////////////////////////// REGULAR SALE ////////////////////////////////////

    /**
     * Puts on sale existing market item.
     */
    function putItemOnSale(
        uint256 itemId,
        uint256 amount,
        uint256 price
    ) public itemExists(itemId) {
        require(price > 0, "SqwidMarket: Price cannot be 0");
        require(amount > 0, "SqwidMarket: Amount cannot be 0");
        require(
            amount <=
                ISqwidERC1155(_idToItem[itemId].nftContract).balanceOf(
                    msg.sender,
                    _idToItem[itemId].tokenId
                ),
            "SqwidMarket: Address balance too low"
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
        _stateToCounter[PositionState.RegularSale].increment();

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
        require(_idToPosition[positionId].amount >= amount, "SqwidMarket: Amount too large");
        uint256 price = _idToPosition[positionId].price;
        require(msg.value == (price * amount), "SqwidMarket: Value sent is not valid");

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
            _stateToCounter[PositionState.RegularSale].decrement();
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
            "SqwidMarket: Only seller can unlist item"
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
        _stateToCounter[PositionState.RegularSale].decrement();

        _updateAvailablePosition(itemId, msg.sender);
    }

    /////////////////////////// AUCTION ////////////////////////////////////

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
            "SqwidMarket: Address balance too low"
        );
        require(amount > 0, "SqwidMarket: Amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 44640, "SqwidMarket: Number of minutes invalid"); // 44,640 min = 1 month
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

        _stateToCounter[PositionState.Auction].increment();

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
        require(
            _idToAuctionData[positionId].deadline >= block.timestamp,
            "SqwidMarket: Auction has ended"
        );
        uint256 totalBid = _idToAuctionData[positionId].addressToAmount[msg.sender] + msg.value;
        require(
            totalBid > _idToAuctionData[positionId].highestBid &&
                totalBid >= _idToAuctionData[positionId].minBid,
            "SqwidMarket: Bid value invalid"
        );

        // Update AuctionData
        _idToAuctionData[positionId].highestBid = totalBid;
        _idToAuctionData[positionId].highestBidder = msg.sender;
        if (msg.value == totalBid) {
            _idToAuctionData[positionId].indexToAddress[
                _idToAuctionData[positionId].totalAddresses
            ] = payable(msg.sender);
            _idToAuctionData[positionId].totalAddresses += 1;
        }
        _idToAuctionData[positionId].addressToAmount[msg.sender] = totalBid;

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
            "SqwidMarket: Deadline not reached"
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
            // Send back bids to other bidders
            uint256 totalAddresses = _idToAuctionData[positionId].totalAddresses;
            for (uint256 i; i < totalAddresses; i++) {
                address addr = _idToAuctionData[positionId].indexToAddress[i];
                uint256 bidAmount = _idToAuctionData[positionId].addressToAmount[addr];
                if (addr != receiver) {
                    addressBalance[addr] += bidAmount;
                }
            }
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
        _stateToCounter[PositionState.Auction].decrement();

        _updateAvailablePosition(itemId, receiver);
    }

    /**
     * Returns addresses and bids of an active auction.
     */
    function fetchAuctionBids(uint256 positionId)
        external
        view
        positionInState(positionId, PositionState.Auction)
        returns (address[] memory, uint256[] memory)
    {
        uint256 totalAddresses = _idToAuctionData[positionId].totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            address currAddress = _idToAuctionData[positionId].indexToAddress[i];
            addresses[i] = currAddress;
            amounts[i] = _idToAuctionData[positionId].addressToAmount[currAddress];
        }

        return (addresses, amounts);
    }

    /////////////////////////// RAFFLE ////////////////////////////////////

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
            "SqwidMarket: Address balance too low"
        );
        require(amount > 0, "SqwidMarket: Amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 44640, "SqwidMarket: Number of minutes invalid"); // 44,640 min = 1 month
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

        _stateToCounter[PositionState.Raffle].increment();

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
            "SqwidMarket: Raffle has ended"
        );
        require(msg.value >= 1 * (10**18), "SqwidMarket: Value sent invalid");

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
            "SqwidMarket: Deadline not reached"
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
            for (uint256 i; i < totalAddresses; i++) {
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
        _stateToCounter[PositionState.Raffle].decrement();

        _updateAvailablePosition(itemId, receiver);
    }

    /**
     * Returns addresses and amounts of an active raffle.
     */
    function fetchRaffleAmounts(uint256 positionId)
        external
        view
        positionInState(positionId, PositionState.Raffle)
        returns (address[] memory, uint256[] memory)
    {
        uint256 totalAddresses = _idToRaffleData[positionId].totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            address currAddress = _idToRaffleData[positionId].indexToAddress[i];
            addresses[i] = currAddress;
            amounts[i] = _idToRaffleData[positionId].addressToAmount[currAddress];
        }

        return (addresses, amounts);
    }

    /////////////////////////// LOAN ////////////////////////////////////

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
            "SqwidMarket: Address balance too low"
        );
        require(loanAmount > 0, "SqwidMarket: Loan amount cannot be 0");
        require(feeAmount >= 0, "SqwidMarket: Fee cannot be negative");
        require(tokenAmount > 0, "SqwidMarket: Token amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 525600, "SqwidMarket: Number of minutes invalid");
        // 1,440 min = 1 day - 525,600 min = 1 year
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

        _stateToCounter[PositionState.Loan].increment();

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
        require(_idToLoanData[positionId].lender == address(0), "SqwidMarket: Loan already funded");
        require(
            msg.value == _idToLoanData[positionId].loanAmount,
            "SqwidMarket: Value sent invalid"
        );

        // Update LoanData
        _idToLoanData[positionId].lender = msg.sender;
        _idToLoanData[positionId].deadline =
            block.timestamp +
            _idToLoanData[positionId].numMinutes *
            1 minutes;

        // // Allocate market fee into owner balance
        uint256 marketFeeAmount = (msg.value * _idToPosition[positionId].marketFee) / 10000;
        addressBalance[owner()] += marketFeeAmount;

        // Transfer funds to borrower
        payable(_idToPosition[positionId].owner).transfer(msg.value - marketFeeAmount);
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
        require(_idToLoanData[positionId].lender != address(0), "SqwidMarket: Loan not funded");
        require(
            msg.value >= _idToLoanData[positionId].loanAmount + _idToLoanData[positionId].feeAmount,
            "SqwidMarket: Value sent invalid"
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
        _stateToCounter[PositionState.Loan].decrement();

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
            "SqwidMarket: Only lender can liquidate"
        );
        require(
            _idToLoanData[positionId].deadline < block.timestamp,
            "SqwidMarket: Deadline not reached"
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
        _stateToCounter[PositionState.Loan].decrement();

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
            "SqwidMarket: Only borrower can unlist"
        );
        require(_idToLoanData[positionId].lender == address(0), "SqwidMarket: Loan already funded");

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
        _stateToCounter[PositionState.Loan].decrement();

        _updateAvailablePosition(itemId, msg.sender);
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
        (address royaltiesReceiver, uint256 royaltiesAmount) = INftRoyalties(_nftContract)
            .royaltyInfo(_tokenId, _grossSaleValue);

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
        if (IERC165(nftContract).supportsInterface(type(INftRoyalties).interfaceId)) {
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

            _stateToCounter[PositionState.Available].increment();
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
        for (uint256 i; i < totalPositionCount; i++) {
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
        for (uint256 i; i < totalPositionCount; i++) {
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
}
