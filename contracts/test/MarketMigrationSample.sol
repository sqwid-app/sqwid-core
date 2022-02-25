// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../@openzeppelin/contracts/utils/Counters.sol";
import "../interface/ISqwidMarketplaceUtil.sol";
import "../interface/ISqwidMigrator.sol";

/**
 * Sample contract that migrated all data from an active market contract.
 */
contract MarketMigrationSample is ISqwidMigrator {
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

    mapping(uint256 => Item) public idToItem;
    mapping(uint256 => Position) public idToPosition;
    mapping(uint256 => AuctionData) public idToAuctionData;
    mapping(uint256 => RaffleData) public idToRaffleData;
    mapping(uint256 => LoanData) public idToLoanData;
    address public immutable marketplace;
    ISqwidMarketplaceUtil public immutable marketplaceUtil;

    constructor(address marketplace_, ISqwidMarketplaceUtil marketplaceUtil_) {
        marketplace = marketplace_;
        marketplaceUtil = marketplaceUtil_;
    }

    function positionClosed(
        uint256 positionId,
        address receiver,
        bool saleCreated
    ) external override {
        require(msg.sender == marketplace, "Migration: Only marketplace can call");

        if (saleCreated) {
            // Retrieve last sale for the item
            uint256 itemId = idToPosition[positionId].itemId;
            ISqwidMarketplaceUtil.ItemResponse memory item = marketplaceUtil.fetchItem(itemId);
            ISqwidMarketplace.ItemSale memory sale = item.sales[item.sales.length - 1];

            // Add sale to item
            idToItem[itemId].sales.push(ItemSale(sale.seller, sale.buyer, sale.price, sale.amount));
        }

        // TODO It would require to do all the necessary updates for the item, remove position
        // (if is not a partial sale), create/update available position, etc
    }

    function fetchItemSales(uint256 itemId) external view returns (ItemSale[] memory) {
        return idToItem[itemId].sales;
    }

    function fetchAuctionBids(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 totalAddresses = idToAuctionData[positionId].totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            address currAddress = idToAuctionData[positionId].indexToAddress[i];
            addresses[i] = currAddress;
            amounts[i] = idToAuctionData[positionId].addressToAmount[currAddress];
        }

        return (addresses, amounts);
    }

    function fetchRaffleAmounts(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 totalAddresses = idToRaffleData[positionId].totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            address currAddress = idToRaffleData[positionId].indexToAddress[i];
            addresses[i] = currAddress;
            amounts[i] = idToRaffleData[positionId].addressToAmount[currAddress];
        }

        return (addresses, amounts);
    }

    function copyItems(uint256 pageSize, uint256 page) external {
        (ISqwidMarketplaceUtil.ItemResponse[] memory items, ) = marketplaceUtil.fetchItems(
            pageSize,
            page
        );
        for (uint256 i; i < items.length; i++) {
            ISqwidMarketplaceUtil.ItemResponse memory itemOld = items[i];
            idToItem[itemOld.itemId].itemId = itemOld.itemId;
            idToItem[itemOld.itemId].nftContract = itemOld.nftContract;
            idToItem[itemOld.itemId].tokenId = itemOld.tokenId;
            idToItem[itemOld.itemId].creator = itemOld.creator;
            idToItem[itemOld.itemId].positionCount = itemOld.positions.length;
            for (uint256 j; j < itemOld.sales.length; j++) {
                ISqwidMarketplace.ItemSale memory sale = itemOld.sales[j];
                idToItem[itemOld.itemId].sales.push(
                    ItemSale(sale.seller, sale.buyer, sale.price, sale.amount)
                );
            }
        }
    }

    function copyAvailable() external {
        uint256 currPage = 1;
        uint256 _totalPages;
        // Available positions
        currPage = 1;
        do {
            (
                ISqwidMarketplaceUtil.PositionResponse[] memory availablePositions,
                uint256 totalPages
            ) = marketplaceUtil.fetchPositionsByState(
                    ISqwidMarketplace.PositionState.Available,
                    100,
                    currPage
                );
            for (uint256 i; i < availablePositions.length; i++) {
                ISqwidMarketplaceUtil.PositionResponse memory positionOld = availablePositions[i];
                idToPosition[positionOld.positionId] = _mapPosition(
                    positionOld,
                    PositionState.Available
                );
            }
            _totalPages = totalPages;
            currPage++;
        } while (_totalPages >= currPage);
    }

    function copyRegular() external {
        uint256 currPage = 1;
        uint256 _totalPages;
        currPage = 1;
        do {
            (
                ISqwidMarketplaceUtil.PositionResponse[] memory salePositions,
                uint256 totalPages
            ) = marketplaceUtil.fetchPositionsByState(
                    ISqwidMarketplace.PositionState.RegularSale,
                    100,
                    currPage
                );
            for (uint256 i; i < salePositions.length; i++) {
                ISqwidMarketplaceUtil.PositionResponse memory positionOld = salePositions[i];
                idToPosition[positionOld.positionId] = _mapPosition(
                    positionOld,
                    PositionState.RegularSale
                );
            }
            _totalPages = totalPages;
            currPage++;
        } while (_totalPages >= currPage);
    }

    function copyAuctions() external {
        uint256 currPage = 1;
        uint256 _totalPages;
        do {
            (
                ISqwidMarketplaceUtil.PositionResponse[] memory auctions,
                uint256 totalPages
            ) = marketplaceUtil.fetchPositionsByState(
                    ISqwidMarketplace.PositionState.Auction,
                    100,
                    currPage
                );
            for (uint256 i; i < auctions.length; i++) {
                ISqwidMarketplaceUtil.PositionResponse memory positionOld = auctions[i];
                idToPosition[positionOld.positionId] = _mapPosition(
                    positionOld,
                    PositionState.Auction
                );
                idToAuctionData[positionOld.positionId].deadline = positionOld.auctionData.deadline;
                idToAuctionData[positionOld.positionId].highestBid = positionOld
                    .auctionData
                    .highestBid;
                idToAuctionData[positionOld.positionId].highestBidder = positionOld
                    .auctionData
                    .highestBidder;
                (address[] memory addresses, uint256[] memory amounts) = marketplaceUtil
                    .fetchAuctionBids(positionOld.positionId);
                idToAuctionData[positionOld.positionId].totalAddresses = addresses.length;
                for (uint256 j; j < addresses.length; j++) {
                    idToAuctionData[positionOld.positionId].indexToAddress[j] = addresses[j];
                    idToAuctionData[positionOld.positionId].addressToAmount[addresses[j]] = amounts[
                        j
                    ];
                }
            }
            _totalPages = totalPages;
            currPage++;
        } while (_totalPages >= currPage);
    }

    function copyRaffles() external {
        uint256 currPage = 1;
        uint256 _totalPages;
        do {
            (
                ISqwidMarketplaceUtil.PositionResponse[] memory raffles,
                uint256 totalPages
            ) = marketplaceUtil.fetchPositionsByState(
                    ISqwidMarketplace.PositionState.Raffle,
                    100,
                    currPage
                );
            for (uint256 i; i < raffles.length; i++) {
                ISqwidMarketplaceUtil.PositionResponse memory positionOld = raffles[i];
                idToPosition[positionOld.positionId] = _mapPosition(
                    positionOld,
                    PositionState.Raffle
                );
                idToRaffleData[positionOld.positionId].deadline = positionOld.raffleData.deadline;
                idToRaffleData[positionOld.positionId].totalValue = positionOld
                    .raffleData
                    .totalValue;
                idToRaffleData[positionOld.positionId].totalAddresses = positionOld
                    .raffleData
                    .totalAddresses;
                (address[] memory addresses, uint256[] memory amounts) = marketplaceUtil
                    .fetchRaffleEntries(positionOld.positionId);
                for (uint256 j; j < addresses.length; j++) {
                    idToRaffleData[positionOld.positionId].indexToAddress[j] = addresses[j];
                    idToRaffleData[positionOld.positionId].addressToAmount[addresses[j]] = amounts[
                        j
                    ];
                }
            }
            _totalPages = totalPages;
            currPage++;
        } while (_totalPages >= currPage);
    }

    function copyLoans() external {
        uint256 currPage = 1;
        uint256 _totalPages;
        do {
            (
                ISqwidMarketplaceUtil.PositionResponse[] memory loans,
                uint256 totalPages
            ) = marketplaceUtil.fetchPositionsByState(
                    ISqwidMarketplace.PositionState.Loan,
                    100,
                    currPage
                );
            for (uint256 i; i < loans.length; i++) {
                ISqwidMarketplaceUtil.PositionResponse memory positionOld = loans[i];
                idToPosition[positionOld.positionId] = _mapPosition(
                    positionOld,
                    PositionState.Loan
                );
                idToLoanData[positionOld.positionId] = LoanData(
                    positionOld.loanData.loanAmount,
                    positionOld.loanData.feeAmount,
                    positionOld.loanData.numMinutes,
                    positionOld.loanData.deadline,
                    positionOld.loanData.lender
                );
            }
            _totalPages = totalPages;
            currPage++;
        } while (_totalPages >= currPage);
    }

    function _mapPosition(
        ISqwidMarketplaceUtil.PositionResponse memory positionOld,
        PositionState state
    ) private pure returns (Position memory) {
        return
            Position(
                positionOld.positionId,
                positionOld.item.itemId,
                positionOld.owner,
                positionOld.amount,
                positionOld.price,
                positionOld.marketFee,
                state
            );
    }
}
