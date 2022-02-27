// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/access/Ownable.sol";
import "../../@openzeppelin/contracts/utils/Counters.sol";
import "../interface/ISqwidMarketplaceUtil.sol";
import "../interface/ISqwidMigrator.sol";

/**
 * Sample contract that migrated all data from an active market contract.
 */
contract MarketMigrationSample is ISqwidMigrator, Ownable {
    using Counters for Counters.Counter;

    enum PositionState {
        Available,
        RegularSale,
        Auction,
        Raffle,
        Loan
    }

    struct Item {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address creator;
        uint256 positionCount;
        ItemSale[] sales;
    }

    struct Position {
        uint256 positionId;
        uint256 itemId;
        address payable owner;
        uint256 amount;
        uint256 price;
        uint256 marketFee;
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

    Counters.Counter public itemIds;
    Counters.Counter public positionIds;
    mapping(PositionState => Counters.Counter) public stateToCounter;
    mapping(uint256 => Item) public idToItem;
    mapping(uint256 => Position) public idToPosition;
    mapping(uint256 => AuctionData) public idToAuctionData;
    mapping(uint256 => RaffleData) public idToRaffleData;
    mapping(uint256 => LoanData) public idToLoanData;
    address public immutable marketplace;
    ISqwidMarketplaceUtil public immutable marketplaceUtil;
    bool public initialized;

    modifier notInitialized() {
        require(!initialized, "Migration: Contract initialized");
        _;
    }

    constructor(address marketplace_, ISqwidMarketplaceUtil marketplaceUtil_) {
        marketplace = marketplace_;
        marketplaceUtil = marketplaceUtil_;
    }

    /**
     * Initializes contract after migrating data
     */
    function initialize() external onlyOwner {
        initialized = true;
    }

    /**
     * Migrates items from old contract.
     */
    function setItems(Item[] memory items) external onlyOwner notInitialized {
        for (uint256 i = 0; i < items.length; i++) {
            Item memory item = items[i];
            idToItem[item.itemId].itemId = item.itemId;
            idToItem[item.itemId].nftContract = item.nftContract;
            idToItem[item.itemId].tokenId = item.tokenId;
            idToItem[item.itemId].creator = item.creator;
            idToItem[item.itemId].positionCount = item.positionCount;
            for (uint256 j; j < item.sales.length; j++) {
                idToItem[item.itemId].sales.push(item.sales[j]);
            }
        }
    }

    /**
     * Migrates available positions from old contract.
     */
    function setPositions(Position[] memory positions) external onlyOwner notInitialized {
        for (uint256 i = 0; i < positions.length; i++) {
            idToPosition[positions[i].positionId] = positions[i];
            stateToCounter[positions[i].state].increment();
        }
    }

    /**
     * Migrates item and position id counters from old contract.
     */
    function setCounters(uint256 _itemIds, uint256 _positionIds) external onlyOwner notInitialized {
        itemIds.reset();
        for (uint256 i = 1; i <= _itemIds; i++) {
            itemIds.increment();
        }

        positionIds.reset();
        for (uint256 i = 1; i <= _positionIds; i++) {
            positionIds.increment();
        }
    }

    /**
     * Only available positions are migrated before initializing the new contract.
     * When open positions (sales, auctions, raffles, loans) are closed, this function
     * is called from old contract, and data is updated.
     */
    function positionClosed(
        uint256 itemId,
        address receiver,
        bool saleCreated
    ) external override {
        require(msg.sender == marketplace, "Migration: Only marketplace can call");

        if (saleCreated) {
            // Retrieve last sale for the item
            ISqwidMarketplaceUtil.ItemResponse memory item = marketplaceUtil.fetchItem(itemId);
            ISqwidMarketplace.ItemSale memory sale = item.sales[item.sales.length - 1];

            // Add sale to item
            idToItem[item.itemId].sales.push(
                ItemSale(sale.seller, sale.buyer, sale.price, sale.amount)
            );
        }

        _updateAvailablePosition(itemId, receiver);
    }

    /**
     * Returns item sales.
     */
    function fetchItemSales(uint256 itemId) external view returns (ItemSale[] memory) {
        return idToItem[itemId].sales;
    }

    /**
     * Creates new position or updates amount in exising one for receiver of tokens.
     */
    function _updateAvailablePosition(uint256 itemId, address tokenOwner) private {
        uint256 receiverPositionId;
        uint256 amount = ISqwidERC1155(idToItem[itemId].nftContract).balanceOf(
            tokenOwner,
            idToItem[itemId].tokenId
        );
        Position memory position = _fetchAvalailablePosition(itemId, tokenOwner);
        if (position.itemId != 0) {
            receiverPositionId = position.itemId;
            idToPosition[receiverPositionId].amount = amount;
        } else {
            positionIds.increment();
            receiverPositionId = positionIds.current();
            idToPosition[receiverPositionId] = Position(
                receiverPositionId,
                itemId,
                payable(tokenOwner),
                amount,
                0,
                0,
                PositionState.Available
            );

            stateToCounter[PositionState.Available].increment();
            idToItem[itemId].positionCount++;
        }
    }

    /**
     * Returns item available position of a certain item and owner.
     */
    function _fetchAvalailablePosition(uint256 itemId, address tokenOwner)
        private
        view
        returns (Position memory)
    {
        uint256 totalPositionCount = positionIds.current();
        for (uint256 i; i < totalPositionCount; i++) {
            if (
                idToPosition[i + 1].itemId == itemId &&
                idToPosition[i + 1].owner == tokenOwner &&
                idToPosition[i + 1].state == PositionState.Available
            ) {
                return idToPosition[i + 1];
            }
        }

        Position memory emptyPosition;
        return emptyPosition;
    }
}
