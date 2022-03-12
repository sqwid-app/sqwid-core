// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ISqwidMarketplace.sol";
import "./ISqwidERC1155.sol";

interface ISqwidMarketplaceUtil {
    struct ItemResponse {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address creator;
        ISqwidMarketplace.ItemSale[] sales;
        ISqwidMarketplace.Position[] positions;
    }

    struct PositionResponse {
        uint256 positionId;
        ISqwidMarketplace.Item item;
        address payable owner;
        uint256 amount;
        uint256 price;
        uint256 marketFee;
        ISqwidMarketplace.PositionState state;
        ISqwidMarketplace.AuctionDataResponse auctionData;
        ISqwidMarketplace.RaffleDataResponse raffleData;
        ISqwidMarketplace.LoanData loanData;
    }

    struct AuctionBidded {
        PositionResponse auction;
        uint256 bidAmount;
    }

    struct RaffleEntered {
        PositionResponse raffle;
        uint256 enteredAmount;
    }

    function setMarketContractAddress(ISqwidMarketplace marketplace_) external;

    function fetchItem(uint256 itemId) external view returns (ItemResponse memory);

    function fetchItems(
        uint256 startIndex,
        uint256 limit,
        bytes memory approvedIds
    ) external view returns (ISqwidMarketplace.Item[] memory items);

    function fetchItemsPage(uint256 pageSize, uint256 pageNumber)
        external
        view
        returns (ItemResponse[] memory items, uint256 totalPages);

    function fetchNumberItems() external view returns (uint256);

    function fetchAddressNumberItemsCreated(address targetAddress) external view returns (uint256);

    function fetchPosition(uint256 positionId) external view returns (PositionResponse memory);

    function fetchPositions(
        ISqwidMarketplace.PositionState state,
        address owner,
        uint256 startIndex,
        uint256 limit,
        bytes memory approvedIds
    ) external view returns (PositionResponse[] memory positions);

    function fetchAddressPositionsPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages);

    function fetchPositionsByStatePage(
        ISqwidMarketplace.PositionState state,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages);

    function fetchAddressNumberPositions(address targetAddress) external view returns (uint256);

    function fetchAuctionBids(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);

    function fetchAddressBidsPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (AuctionBidded[] memory bids, uint256 totalPages);

    function fetchAddressNumberBids(address targetAddress) external view returns (uint256);

    function fetchRaffleEntries(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);

    function fetchAddressRafflesPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (RaffleEntered[] memory raffles, uint256 totalPages);

    function fetchAddressNumberRaffles(address targetAddress) external view returns (uint256);

    function fetchAddressLoansPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (PositionResponse[] memory loans, uint256 totalPages);

    function fetchAddressNumberLoans(address targetAddress) external view returns (uint256);
}
