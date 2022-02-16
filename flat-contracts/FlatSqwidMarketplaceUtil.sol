// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ISqwidMigrator {
    function positionClosed(
        uint256 positionId,
        address receiver,
        bool saleCreated
    ) external;
}

interface ISqwidERC1155 {
    function mint(
        address to,
        uint256 amount,
        string memory tokenURI,
        string calldata mimeType_,
        address royaltyRecipient,
        uint256 royaltyValue
    ) external returns (uint256);

    function mintBatch(
        address to,
        uint256[] memory amounts,
        string[] memory tokenURIs,
        string[] calldata mimeTypes,
        address[] memory royaltyRecipients,
        uint256[] memory royaltyValues
    ) external returns (uint256[] memory);

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function wrapERC721(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_
    ) external returns (uint256);

    function wrapERC1155(
        address extNftContract,
        uint256 extTokenId,
        string calldata mimeType_,
        uint256 amount
    ) external returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address account, address operator) external view returns (bool);

    function mimeType(uint256 tokenId) external view returns (string memory);
}

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

contract SqwidMarketplaceUtil is Ownable {
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

    ISqwidMarketplace public marketplace;

    constructor(ISqwidMarketplace marketplace_) {
        marketplace = marketplace_;
    }

    /**
     * Sets new market contract address.
     */
    function setMarketContractAddress(ISqwidMarketplace marketplace_) external onlyOwner {
        marketplace = marketplace_;
    }

    /**
     * Returns item and all its item positions.
     */
    function fetchItem(uint256 itemId) public view returns (ItemResponse memory) {
        ISqwidMarketplace.Item memory item = marketplace.fetchItem(itemId);
        require(item.itemId > 0, "SqwidMarketUtil: Item not found");

        return
            ItemResponse(
                itemId,
                item.nftContract,
                item.tokenId,
                item.creator,
                item.sales,
                _fetchPositionsByItemId(itemId)
            );
    }

    /**
     * Returns all items and all its item positions.
     */
    function fetchAllItems() external view returns (ItemResponse[] memory) {
        uint256 totalItemCount = marketplace.currentItemId();

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
        external
        view
        returns (ItemResponse[] memory)
    {
        // Get total number of items created by target address
        uint256 totalItemCount = marketplace.currentItemId();
        uint256 itemCount = 0;
        for (uint256 i; i < totalItemCount; i++) {
            if (marketplace.fetchItem(i + 1).creator == targetAddress) {
                itemCount += 1;
            }
        }

        // Initialize array
        ItemResponse[] memory items = new ItemResponse[](itemCount);

        // Fill array
        uint256 currentIndex = 0;
        for (uint256 i; i < totalItemCount; i++) {
            if (marketplace.fetchItem(i + 1).creator == targetAddress) {
                items[currentIndex] = fetchItem(i + 1);
                currentIndex += 1;
            }
        }

        return items;
    }

    /**
     * Returns item position.
     */
    function fetchPosition(uint256 positionId) public view returns (PositionResponse memory) {
        ISqwidMarketplace.Position memory position = marketplace.fetchPosition(positionId);
        require(position.positionId > 0, "SqwidMarketUtil: Position not found");

        ISqwidMarketplace.AuctionDataResponse memory auctionData;
        ISqwidMarketplace.RaffleDataResponse memory raffleData;
        ISqwidMarketplace.LoanData memory loanData;
        ISqwidMarketplace.Item memory item = marketplace.fetchItem(position.itemId);
        uint256 amount = position.amount;

        if (position.state == ISqwidMarketplace.PositionState.Available) {
            amount = ISqwidERC1155(item.nftContract).balanceOf(position.owner, item.tokenId);
        } else if (position.state == ISqwidMarketplace.PositionState.Auction) {
            auctionData = marketplace.fetchAuctionData(positionId);
        } else if (position.state == ISqwidMarketplace.PositionState.Raffle) {
            raffleData = marketplace.fetchRaffleData(positionId);
        } else if (position.state == ISqwidMarketplace.PositionState.Loan) {
            loanData = marketplace.fetchLoanData(positionId);
        }

        return
            PositionResponse(
                positionId,
                item,
                position.owner,
                amount,
                position.price,
                position.marketFee,
                position.state,
                auctionData,
                raffleData,
                loanData
            );
    }

    /**
     * Returns items positions from an address.
     */
    function fetchAddressPositions(address targetAddress)
        external
        view
        returns (PositionResponse[] memory)
    {
        // Get total number of items on sale by target address
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 positionCount = 0;
        uint256 currentIndex = 0;
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.owner == targetAddress) {
                positionCount += 1;
            }
        }

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](positionCount);

        // Fill array
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.owner == targetAddress) {
                positions[currentIndex] = fetchPosition(i + 1);
                currentIndex += 1;
            }
        }

        return positions;
    }

    /**
     * Returns market item positions for a given state.
     */
    function fetchPositionsByState(ISqwidMarketplace.PositionState state)
        external
        view
        returns (PositionResponse[] memory)
    {
        uint256 currentIndex = 0;
        uint256 stateCount = marketplace.fetchStateCount(state);

        // Initialize array
        PositionResponse[] memory positions = new PositionResponse[](stateCount);

        // Fill array
        uint256 totalPositionCount = marketplace.currentPositionId();
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.positionId > 0 && position.state == state) {
                positions[currentIndex] = fetchPosition(i + 1);
                currentIndex += 1;
            }
        }

        return positions;
    }

    /**
     * Returns addresses and bids of an active auction.
     */
    function fetchAuctionBids(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        ISqwidMarketplace.Position memory position = marketplace.fetchPosition(positionId);
        require(
            position.state == ISqwidMarketplace.PositionState.Auction,
            "SqwidMarketUtil: Position on wrong state"
        );

        uint256 totalAddresses = marketplace.fetchAuctionData(positionId).totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            (address addr, uint256 amount) = marketplace.fetchBid(positionId, i);
            addresses[i] = addr;
            amounts[i] = amount;
        }

        return (addresses, amounts);
    }

    /**
     * Returns addresses and amounts of an active raffle.
     */
    function fetchRaffleEntries(uint256 positionId)
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        ISqwidMarketplace.Position memory position = marketplace.fetchPosition(positionId);
        require(
            position.state == ISqwidMarketplace.PositionState.Raffle,
            "SqwidMarketUtil: Position on wrong state"
        );

        uint256 totalAddresses = marketplace.fetchRaffleData(positionId).totalAddresses;

        // Initialize array
        address[] memory addresses = new address[](totalAddresses);
        uint256[] memory amounts = new uint256[](totalAddresses);

        // Fill arrays
        for (uint256 i; i < totalAddresses; i++) {
            (address addr, uint256 amount) = marketplace.fetchRaffleEntry(positionId, i);
            addresses[i] = addr;
            amounts[i] = amount;
        }

        return (addresses, amounts);
    }

    /**
     * Returns item positions of a certain item.
     */
    function _fetchPositionsByItemId(uint256 itemId)
        private
        view
        returns (ISqwidMarketplace.Position[] memory)
    {
        // Initialize array
        ISqwidMarketplace.Position[] memory items = new ISqwidMarketplace.Position[](
            marketplace.fetchItem(itemId).positionCount
        );

        // Fill array
        uint256 totalPositionCount = marketplace.currentPositionId();

        uint256 currentIndex = 0;
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.itemId == itemId) {
                items[currentIndex] = position;
                currentIndex++;
            }
        }

        return items;
    }
}
