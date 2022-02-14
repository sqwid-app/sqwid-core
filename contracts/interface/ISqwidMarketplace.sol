// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ISqwidERC1155.sol";
import "./ISqwidMigrator.sol";

interface ISqwidMarketplace {
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

    function transferOwnership(address newOwner) external;

    function setMarketFee(uint16 marketFee_, PositionState typeFee) external;

    function setMimeTypeFee(uint256 mimeTypeFee_) external;

    function setNftContractAddress(ISqwidERC1155 sqwidERC1155_) external;

    function setMigratorAddress(ISqwidMigrator sqwidMigrator_) external;

    function withdraw() external;

    function currentItemId() external view returns (uint256);

    function currentPositionId() external view returns (uint256);

    function fetchItem(uint256 itemId) external view returns (Item memory);

    function fetchPosition(uint256 positionId) external view returns (Position memory);

    function fetchStateCount(PositionState state) external view returns (uint256);

    function fetchAuctionData(uint256 positionId)
        external
        view
        returns (AuctionDataResponse memory);

    function fetchBid(uint256 positionId, uint256 bidIndex)
        external
        view
        returns (address, uint256);

    function fetchRaffleData(uint256 positionId) external view returns (RaffleDataResponse memory);

    function fetchRaffleEntry(uint256 positionId, uint256 entryIndex)
        external
        view
        returns (address, uint256);

    function fetchLoanData(uint256 positionId) external view returns (LoanData memory);
}
