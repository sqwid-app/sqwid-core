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

    function fetchItem(uint256 itemId) external view returns (ItemResponse memory);

    function fetchAllItems() external view returns (ItemResponse[] memory);

    function fetchAddressItemsCreated(address targetAddress)
        external
        view
        returns (ItemResponse[] memory);

    function fetchPosition(uint256 positionId) external view returns (PositionResponse memory);

    function fetchAddressPositions(address targetAddress)
        external
        view
        returns (PositionResponse[] memory);

    function fetchPositionsByState(ISqwidMarketplace.PositionState state)
        external
        view
        returns (PositionResponse[] memory);

    function fetchAuctionBids(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);

    function fetchRaffleEntries(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory);
}
