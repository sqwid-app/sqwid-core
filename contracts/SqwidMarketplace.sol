// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/Counters.sol";
import "../@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ISqwidERC1155.sol";
import "./interface/INftRoyalties.sol";
import "./interface/ISqwidMigrator.sol";

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

    struct AuctionDataResponse {
        uint256 deadline;
        uint256 minBid;
        address highestBidder;
        uint256 highestBid;
        uint256 totalAddresses;
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
    // contractAddress => (tokenId => isRegistered)
    mapping(address => mapping(uint256 => bool)) private _registeredTokens;
    // itemId => (ownerAddress => availablePositionId)
    mapping(uint256 => mapping(address => uint256)) private _itemAvailablePositions;

    mapping(address => uint256) public addressBalance;
    mapping(PositionState => uint256) public marketFees;
    ISqwidERC1155 public sqwidERC1155;
    ISqwidMigrator public sqwidMigrator;

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

    event BidCreated(uint256 indexed positionId, address indexed bidder, uint256 indexed value);

    event RaffleEntered(uint256 indexed positionId, address indexed addr, uint256 indexed value);

    event LoanFunded(uint256 indexed positionId, address indexed funder);

    event BalanceUpdated(address indexed addr, uint256 indexed value);

    modifier itemExists(uint256 itemId) {
        require(_idToItem[itemId].itemId > 0, "SqwidMarket: Item not found");
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

    modifier isLastVersion() {
        require(address(sqwidMigrator) == address(0), "SqwidMarket: Not last market version");
        _;
    }

    constructor(uint256 marketFee_, ISqwidERC1155 sqwidERC1155_) {
        marketFees[PositionState.RegularSale] = marketFee_;
        marketFees[PositionState.Auction] = marketFee_;
        marketFees[PositionState.Raffle] = marketFee_;
        marketFees[PositionState.Loan] = marketFee_;
        sqwidERC1155 = sqwidERC1155_;
    }

    /**
     * Sets market fee percentage with two decimal points.
     * E.g. 250 --> 2.5%
     */
    function setMarketFee(uint16 marketFee_, PositionState typeFee) external onlyOwner {
        require(marketFee_ <= 1000, "SqwidMarket: Fee higher than 1000");
        require(typeFee != PositionState.Available, "SqwidMarket: Invalid fee type");
        marketFees[typeFee] = marketFee_;
    }

    /**
     * Sets new NFT contract address.
     */
    function setNftContractAddress(ISqwidERC1155 sqwidERC1155_) external onlyOwner {
        sqwidERC1155 = sqwidERC1155_;
    }

    /**
     * Sets new Marketplace contract address.
     */
    function setMigratorAddress(ISqwidMigrator sqwidMigrator_) external onlyOwner {
        sqwidMigrator = sqwidMigrator_;
    }

    /**
     * Withdraws available balance from sender.
     */
    function withdraw() external {
        uint256 amount = addressBalance[msg.sender];
        require(amount > 0, "SqwidMarket: No Reef to be claimed");

        addressBalance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{ value: amount }("");
        require(success, "SqwidMarket: Error sending REEF");

        emit BalanceUpdated(msg.sender, 0);
    }

    /**
     * Mints new SqwidERC1155 token and adds it to the marketplace.
     */
    function mint(
        uint256 amount,
        string memory tokenURI,
        string calldata mimeType,
        address royaltyRecipient,
        uint256 royaltyValue
    ) external {
        uint256 tokenId = sqwidERC1155.mint(
            msg.sender,
            amount,
            tokenURI,
            mimeType,
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
        string[] calldata mimeTypes,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues
    ) external {
        uint256[] memory tokenIds = sqwidERC1155.mintBatch(
            msg.sender,
            amounts,
            tokenURIs,
            mimeTypes,
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
    function createItem(uint256 tokenId) public isLastVersion returns (uint256) {
        require(
            sqwidERC1155.balanceOf(msg.sender, tokenId) > 0,
            "SqwidMarket: Address balance too low"
        );
        require(
            !_registeredTokens[address(sqwidERC1155)][tokenId],
            "SqwidMarketplace: Item already exists"
        );

        // Map new Item
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        _idToItem[itemId].itemId = itemId;
        _idToItem[itemId].nftContract = address(sqwidERC1155);
        _idToItem[itemId].tokenId = tokenId;
        _idToItem[itemId].creator = msg.sender;

        _updateAvailablePosition(itemId, msg.sender);

        _registeredTokens[address(sqwidERC1155)][tokenId] = true;

        emit ItemCreated(itemId, address(sqwidERC1155), tokenId, msg.sender);

        return itemId;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// AVAILABLE ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    /**
     * Registers in the marketplace the ownership of an existing item.
     */
    function addAvailableTokens(uint256 itemId) public isLastVersion itemExists(itemId) {
        require(
            ISqwidERC1155(_idToItem[itemId].nftContract).balanceOf(
                msg.sender,
                _idToItem[itemId].tokenId
            ) > 0,
            "SqwidMarket: Address balance too low"
        );
        require(
            _itemAvailablePositions[itemId][msg.sender] == 0,
            "SqwidMarket: Item already registered"
        );

        _updateAvailablePosition(itemId, msg.sender);
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// REGULAR SALE /////////////////////////////////
    //////////////////////////////////////////////////////////////////////////
    /**
     * Puts on sale existing market item.
     */
    function putItemOnSale(
        uint256 itemId,
        uint256 amount,
        uint256 price
    ) public isLastVersion itemExists(itemId) {
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
        uint256 marketFee = marketFees[PositionState.RegularSale];
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

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, msg.sender, true);
        }
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

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, msg.sender, false);
        }
    }

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// AUCTION ////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////

    /**
     * Creates an auction from an existing market item.
     */
    function createItemAuction(
        uint256 itemId,
        uint256 amount,
        uint256 numMinutes,
        uint256 minBid
    ) public isLastVersion itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            amount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarket: Address balance too low"
        );
        require(amount > 0, "SqwidMarket: Amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 44640, "SqwidMarket: Number of minutes invalid"); // 44,640 min = 1 month

        // Transfer ownership of the token to this contract
        ISqwidERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        // Map new Position
        _positionIds.increment();
        uint256 positionId = _positionIds.current();
        uint256 marketFee = marketFees[PositionState.Auction];
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

        emit BidCreated(positionId, msg.sender, msg.value);
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
            // Update balance to other bidders
            uint256 totalAddresses = _idToAuctionData[positionId].totalAddresses;
            for (uint256 i; i < totalAddresses; i++) {
                address addr = _idToAuctionData[positionId].indexToAddress[i];
                uint256 bidAmount = _idToAuctionData[positionId].addressToAmount[addr];
                if (addr != receiver) {
                    _updateBalance(addr, bidAmount);
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

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, receiver, receiver != seller);
        }
    }

    ///////////////////////////////////////////////////////////////////////
    /////////////////////////// RAFFLE ////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /**
     * Creates a raffle from an existing market item.
     */
    function createItemRaffle(
        uint256 itemId,
        uint256 amount,
        uint256 numMinutes
    ) public isLastVersion itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            amount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarket: Address balance too low"
        );
        require(amount > 0, "SqwidMarket: Amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 44640, "SqwidMarket: Number of minutes invalid"); // 44,640 min = 1 month

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
        uint256 marketFee = marketFees[PositionState.Raffle];
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
     * @notice Takes amounts received with an accuracy of 1 REEF, so the fractional part of the
     *         amount received will be discarded.
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
        require(msg.value >= 1 * 1e18, "SqwidMarket: Value sent invalid");

        uint256 value = msg.value / 1e18;

        // Update RaffleData
        if (!(_idToRaffleData[positionId].addressToAmount[msg.sender] > 0)) {
            _idToRaffleData[positionId].indexToAddress[
                _idToRaffleData[positionId].totalAddresses
            ] = payable(msg.sender);
            _idToRaffleData[positionId].totalAddresses += 1;
        }
        _idToRaffleData[positionId].addressToAmount[msg.sender] += value;
        _idToRaffleData[positionId].totalValue += value;

        emit RaffleEntered(positionId, msg.sender, msg.value);
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
                    _createItemTransaction(positionId, receiver, totalValue * 1e18, amount);
                    // Add sale to item
                    _idToItem[itemId].sales.push(
                        ItemSale(seller, receiver, totalValue * 1e18, amount)
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

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, receiver, receiver != seller);
        }
    }

    /////////////////////////////////////////////////////////////////////
    /////////////////////////// LOAN ////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    /**
     * Creates a loan from an existing market item.
     */
    function createItemLoan(
        uint256 itemId,
        uint256 loanAmount,
        uint256 feeAmount,
        uint256 tokenAmount,
        uint256 numMinutes
    ) public isLastVersion itemExists(itemId) {
        address nftContract = _idToItem[itemId].nftContract;
        uint256 tokenId = _idToItem[itemId].tokenId;
        require(
            tokenAmount <= ISqwidERC1155(nftContract).balanceOf(msg.sender, tokenId),
            "SqwidMarket: Address balance too low"
        );
        require(loanAmount > 0, "SqwidMarket: Loan amount cannot be 0");
        require(tokenAmount > 0, "SqwidMarket: Token amount cannot be 0");
        require(numMinutes >= 1 && numMinutes <= 525600, "SqwidMarket: Number of minutes invalid");
        // 1,440 min = 1 day - 525,600 min = 1 year

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
        uint256 marketFee = marketFees[PositionState.Loan];
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

        // Allocate market fee into owner balance
        uint256 marketFeeAmount = (msg.value * _idToPosition[positionId].marketFee) / 10000;
        _updateBalance(owner(), marketFeeAmount);

        // Transfer funds to borrower
        (bool success, ) = _idToPosition[positionId].owner.call{
            value: msg.value - marketFeeAmount
        }("");
        require(success, "SqwidMarketplace: Error sending REEF");

        emit LoanFunded(positionId, msg.sender);
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
        address lender = _idToLoanData[positionId].lender;
        require(lender != address(0), "SqwidMarket: Loan not funded");
        require(
            msg.value >= _idToLoanData[positionId].loanAmount + _idToLoanData[positionId].feeAmount,
            "SqwidMarket: Value sent invalid"
        );

        // Transfer funds to lender
        (bool success, ) = lender.call{ value: msg.value }("");
        if (!success) {
            _updateBalance(lender, msg.value);
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
        delete _idToLoanData[positionId];
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _stateToCounter[PositionState.Loan].decrement();

        _updateAvailablePosition(itemId, borrower);

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, borrower, false);
        }
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
        delete _idToLoanData[positionId];
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _stateToCounter[PositionState.Loan].decrement();

        _updateAvailablePosition(itemId, msg.sender);

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, msg.sender, false);
        }
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
        delete _idToLoanData[positionId];
        delete _idToPosition[positionId];
        emit PositionDelete(positionId);
        _idToItem[itemId].positionCount--;
        _stateToCounter[PositionState.Loan].decrement();

        _updateAvailablePosition(itemId, msg.sender);

        if (address(sqwidMigrator) != address(0)) {
            sqwidMigrator.positionClosed(itemId, msg.sender, false);
        }
    }

    ////////////////////////////////////////////////////////////////////////
    /////////////////////////// GETTERS ////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////

    function currentItemId() external view returns (uint256) {
        return _itemIds.current();
    }

    function currentPositionId() external view returns (uint256) {
        return _positionIds.current();
    }

    function fetchItem(uint256 itemId) external view returns (Item memory) {
        return _idToItem[itemId];
    }

    function fetchPosition(uint256 positionId) external view returns (Position memory) {
        return _idToPosition[positionId];
    }

    function fetchStateCount(PositionState state) external view returns (uint256) {
        return _stateToCounter[state].current();
    }

    function fetchAuctionData(uint256 positionId)
        external
        view
        returns (AuctionDataResponse memory)
    {
        return
            AuctionDataResponse(
                _idToAuctionData[positionId].deadline,
                _idToAuctionData[positionId].minBid,
                _idToAuctionData[positionId].highestBidder,
                _idToAuctionData[positionId].highestBid,
                _idToAuctionData[positionId].totalAddresses
            );
    }

    function fetchBid(uint256 positionId, uint256 bidIndex)
        external
        view
        returns (address, uint256)
    {
        address addr = _idToAuctionData[positionId].indexToAddress[bidIndex];
        return (addr, _idToAuctionData[positionId].addressToAmount[addr]);
    }

    function fetchRaffleData(uint256 positionId) external view returns (RaffleDataResponse memory) {
        return
            RaffleDataResponse(
                _idToRaffleData[positionId].deadline,
                _idToRaffleData[positionId].totalValue,
                _idToRaffleData[positionId].totalAddresses
            );
    }

    function fetchRaffleEntry(uint256 positionId, uint256 entryIndex)
        external
        view
        returns (address, uint256)
    {
        address addr = _idToRaffleData[positionId].indexToAddress[entryIndex];
        return (addr, _idToRaffleData[positionId].addressToAmount[addr]);
    }

    function fetchLoanData(uint256 positionId) external view returns (LoanData memory) {
        return _idToLoanData[positionId];
    }

    //////////////////////////////////////////////////////////////////////
    /////////////////////////// UTILS ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////

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
            (bool success, ) = royaltiesReceiver.call{ value: royaltiesAmount }("");
            if (!success) {
                _updateBalance(royaltiesReceiver, royaltiesAmount);
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
        _updateBalance(owner(), marketFeeAmount);

        uint256 netSaleValue = saleValue - marketFeeAmount;

        // Transfer value of the transaction to the seller
        (bool success, ) = seller.call{ value: netSaleValue }("");
        if (!success) {
            _updateBalance(seller, netSaleValue);
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
        uint256 positionId = _itemAvailablePositions[itemId][tokenOwner];

        if (positionId != 0) {
            receiverPositionId = positionId;
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
            _itemAvailablePositions[itemId][tokenOwner] = receiverPositionId;
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
     * Increments balance of address and emits event.
     */
    function _updateBalance(address addr, uint256 value) private {
        addressBalance[addr] += value;
        emit BalanceUpdated(addr, addressBalance[addr]);
    }
}
