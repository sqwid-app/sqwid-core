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

    function fetchNumberItems() external view returns (uint256);

    function fetchItemsList(uint256[] memory itemIds)
        external
        view
        returns (ItemResponse[] memory items, uint256 totalPages);

    function fetchItems(
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (ItemResponse[] memory items, uint256 totalPages);

    function fetchAddressNumberItemsCreated(address targetAddress) external view returns (uint256);

    function fetchAddressItemsCreated(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (ItemResponse[] memory items, uint256 totalPages);

    function fetchPosition(uint256 positionId) external view returns (PositionResponse memory);

    function fetchPositionsList(uint256[] memory positionIds)
        external
        view
        returns (PositionResponse[] memory positions);

    function fetchAddressNumberPositions(address targetAddress) external view returns (uint256);

    function fetchAddressPositions(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages);

    function fetchNumberPositionsByState(ISqwidMarketplace.PositionState state)
        external
        view
        returns (uint256);

    function fetchPositionsByState(
        ISqwidMarketplace.PositionState state,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages);

    function fetchAuctionBids(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);

    function fetchAddressNumberBids(address targetAddress) external view returns (uint256);

    function fetchAddressBids(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (AuctionBidded[] memory bids, uint256 totalPages);

    function fetchRaffleEntries(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);

    function fetchAddressNumberRaffles(address targetAddress) external view returns (uint256);

    function fetchAddressRaffles(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (RaffleEntered[] memory raffles, uint256 totalPages);

    function fetchAddressNumberLoans(address targetAddress) external view returns (uint256);

    function fetchAddressLoans(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    ) external view returns (PositionResponse[] memory loans, uint256 totalPages);
}
