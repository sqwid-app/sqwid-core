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

    struct AuctionBidded {
        PositionResponse auction;
        uint256 bidAmount;
    }

    struct RaffleEntered {
        PositionResponse raffle;
        uint256 enteredAmount;
    }

    ISqwidMarketplace public marketplace;

    modifier pagination(uint256 pageNumber, uint256 pageSize) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");
        _;
    }

    modifier idsSize(uint256 size) {
        require(size <= 100 && size > 0, "SqwidMarketUtil: Invalid number of ids");
        _;
    }

    constructor(ISqwidMarketplace marketplace_) {
        marketplace = marketplace_;
    }

    /**
     * Sets new market contract address.
     */
    function setMarketContractAddress(ISqwidMarketplace marketplace_) external onlyOwner {
        marketplace = marketplace_;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// ITEMS ////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////
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
     * Returns <limit> valid items for a given state starting at <startIndex> (where the itemIds
     * are part of approvedIds)
     */
    function fetchItems(
        uint256 startIndex,
        uint256 limit,
        bytes memory approvedIds
    ) external view returns (ISqwidMarketplace.Item[] memory items) {
        require(limit >= 1 && limit <= 100, "SqwidMarketUtil: Invalid limit");
        uint256 totalItems = marketplace.currentItemId();
        if (startIndex == 0) {
            startIndex = totalItems;
        }
        require(
            startIndex >= 1 && startIndex <= totalItems,
            "SqwidMarketUtil: Invalid start index"
        );
        require(approvedIds.length > 0, "SqwidMarketUtil: Invalid approvedIds");
        if (startIndex < limit) {
            limit = startIndex;
        }

        items = new ISqwidMarketplace.Item[](limit);
        uint256 count;
        for (uint256 i = startIndex; i > 0; i--) {
            if (_checkExistsBytes(i, approvedIds)) {
                items[count] = marketplace.fetchItem(i);
                count++;
                if (count == limit) break;
            }
        }
    }

    /**
     * Returns items paginated.
     */
    function fetchItemsPage(uint256 pageSize, uint256 pageNumber)
        external
        view
        pagination(pageSize, pageNumber)
        returns (ISqwidMarketplace.Item[] memory items, uint256 totalPages)
    {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalItemCount = marketplace.currentItemId();
        if (totalItemCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (items, 0);
        }
        if (startIndex > totalItemCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > totalItemCount) {
            endIndex = totalItemCount;
        }

        // Fill array
        items = new ISqwidMarketplace.Item[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = startIndex; i <= endIndex; i++) {
            items[count] = marketplace.fetchItem(i);
            count++;
        }

        // Set total number pages
        totalPages = (totalItemCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns total number of items.
     */
    function fetchNumberItems() public view returns (uint256) {
        return marketplace.currentItemId();
    }

    /**
     * Returns number of items created by an address.
     */
    function fetchAddressNumberItemsCreated(address targetAddress) public view returns (uint256) {
        uint256 createdItemCount = 0;
        uint256 totalItemCount = marketplace.currentItemId();

        for (uint256 i; i < totalItemCount; i++) {
            if (marketplace.fetchItem(i + 1).creator == targetAddress) {
                createdItemCount++;
            }
        }

        return createdItemCount;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// POSITIONS ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

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
     * Returns <limit> valid positions for a given state starting at <startIndex> (where the itemIds
     * are part of approvedIds) of owner != address (0) it also filters by owner
     */
    function fetchPositions(
        ISqwidMarketplace.PositionState state,
        address owner,
        uint256 startIndex,
        uint256 limit,
        bytes memory approvedIds
    ) external view returns (PositionResponse[] memory positions) {
        require(limit >= 1 && limit <= 100, "SqwidMarketUtil: Invalid limit");
        uint256 totalPositions = marketplace.currentPositionId();
        if (startIndex == 0) {
            startIndex = totalPositions;
        }
        require(
            startIndex >= 1 && startIndex <= totalPositions,
            "SqwidMarketUtil: Invalid start index"
        );
        require(approvedIds.length > 0, "SqwidMarketUtil: Invalid approvedIds");
        if (startIndex < limit) {
            limit = startIndex;
        }

        positions = new PositionResponse[](limit);
        uint256 count;
        for (uint256 i = startIndex; i > 0; i--) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i);
            if (
                (owner != address(0) ? position.owner == owner : true) &&
                position.state == state &&
                position.amount > 0 &&
                _checkExistsBytes(position.itemId, approvedIds)
            ) {
                positions[count] = fetchPosition(i);
                if (positions[count].amount > 0) {
                    count++;
                    if (count == limit) break;
                } else {
                    delete positions[count];
                }
            }
        }
    }

    /**
     * Returns items positions from an address paginated.
     */
    function fetchAddressPositionsPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    )
        external
        view
        pagination(pageSize, pageNumber)
        returns (PositionResponse[] memory positions, uint256 totalPages)
    {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressPositionCount;
        uint256 firstMatch;
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.owner == targetAddress) {
                addressPositionCount++;
                if (addressPositionCount == startIndex) {
                    firstMatch = i + 1;
                }
            }
        }
        if (addressPositionCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (positions, 0);
        }
        if (startIndex > addressPositionCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > addressPositionCount) {
            endIndex = addressPositionCount;
        }
        uint256 size = endIndex - startIndex + 1;

        // Fill array
        positions = new PositionResponse[](size);
        uint256 count;
        for (uint256 i = firstMatch; count < size; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i);
            if (position.owner == targetAddress) {
                positions[count] = fetchPosition(i);
                count++;
            }
        }

        // Set total number of pages
        totalPages = (addressPositionCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns item positions for a given state paginated.
     */
    function fetchPositionsByStatePage(
        ISqwidMarketplace.PositionState state,
        uint256 pageSize,
        uint256 pageNumber
    )
        external
        view
        pagination(pageSize, pageNumber)
        returns (PositionResponse[] memory positions, uint256 totalPages)
    {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalStatePositions = marketplace.fetchStateCount(state);
        if (totalStatePositions == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (positions, 0);
        }
        if (startIndex > totalStatePositions) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > totalStatePositions) {
            endIndex = totalStatePositions;
        }
        uint256 size = endIndex - startIndex + 1;

        // Fill array
        positions = new PositionResponse[](size);
        uint256 count;
        uint256 statePositionCount;
        for (uint256 i = 1; count < size; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i);
            if (position.positionId > 0 && position.state == state) {
                statePositionCount++;
                if (statePositionCount >= startIndex) {
                    positions[count] = fetchPosition(i);
                    count++;
                }
            }
        }

        // Set total number pages
        totalPages = (totalStatePositions + pageSize - 1) / pageSize;
    }

    /**
     * Returns number of items positions from an address.
     */
    function fetchAddressNumberPositions(address targetAddress) external view returns (uint256) {
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 positionCount = 0;
        for (uint256 i; i < totalPositionCount; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i + 1);
            if (position.owner == targetAddress) {
                positionCount++;
            }
        }

        return positionCount;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// AUCTIONS /////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    /**
     * Returns addresses and bids of an active auction.
     */
    function fetchAuctionBids(uint256 positionId)
        public
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
     * Returns bids by an address paginated.
     */
    function fetchAddressBidsPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    )
        external
        view
        pagination(pageSize, pageNumber)
        returns (AuctionBidded[] memory bids, uint256 totalPages)
    {
        if (newestToOldest) {
            return _fetchAddressBidsReverse(targetAddress, pageSize, pageNumber);
        } else {
            return _fetchAddressBids(targetAddress, pageSize, pageNumber);
        }
    }

    /**
     * Returns number of bids by an address.
     */
    function fetchAddressNumberBids(address targetAddress) external view returns (uint256) {
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressBidCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Auction) {
                (address[] memory addresses, ) = fetchAuctionBids(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressBidCount++;
                    }
                }
            }
        }

        return addressBidCount;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// RAFFLES //////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    /**
     * Returns addresses and amounts of an active raffle.
     */
    function fetchRaffleEntries(uint256 positionId)
        public
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
     * Returns active raffles entered by an address paginated.
     */
    function fetchAddressRafflesPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    )
        external
        view
        pagination(pageSize, pageNumber)
        returns (RaffleEntered[] memory raffles, uint256 totalPages)
    {
        if (newestToOldest) {
            return _fetchAddressRafflesReverse(targetAddress, pageSize, pageNumber);
        } else {
            return _fetchAddressRaffles(targetAddress, pageSize, pageNumber);
        }
    }

    /**
     * Returns number active raffles entered by an address.
     */
    function fetchAddressNumberRaffles(address targetAddress) external view returns (uint256) {
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressRaffleCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Raffle) {
                (address[] memory addresses, ) = fetchRaffleEntries(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressRaffleCount++;
                    }
                }
            }
        }

        return addressRaffleCount;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// LOANS ////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    /**
     * Returns active loans funded by an address paginated.
     */
    function fetchAddressLoansPage(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber,
        bool newestToOldest
    )
        external
        view
        pagination(pageSize, pageNumber)
        returns (PositionResponse[] memory loans, uint256 totalPages)
    {
        if (newestToOldest) {
            return _fetchAddressLoansReverse(targetAddress, pageSize, pageNumber);
        } else {
            return _fetchAddressLoans(targetAddress, pageSize, pageNumber);
        }
    }

    /**
     * Returns number active loans funded by an address paginated.
     */
    function fetchAddressNumberLoans(address targetAddress) external view returns (uint256) {
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressLoanCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (
                marketplace.fetchLoanData(i + 1).lender == targetAddress &&
                marketplace.fetchPosition(i + 1).positionId > 0
            ) {
                addressLoanCount++;
            }
        }

        return addressLoanCount;
    }

    //////////////////////////////////////////////////////////////////////////
    /////////////////////////// PRIVATE //////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

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

    /**
     * Returns bids by an address paginated (starting from first element).
     */
    function _fetchAddressBids(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (AuctionBidded[] memory bids, uint256 totalPages) {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressBidCount;
        uint256 firstMatch;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Auction) {
                (address[] memory addresses, ) = fetchAuctionBids(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressBidCount++;
                        if (addressBidCount == startIndex) {
                            firstMatch = i + 1;
                        }
                        break;
                    }
                }
            }
        }
        if (addressBidCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (bids, 0);
        }
        if (startIndex > addressBidCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > addressBidCount) {
            endIndex = addressBidCount;
        }

        // Fill array
        bids = new AuctionBidded[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = firstMatch; count < endIndex - startIndex + 1; i++) {
            if (marketplace.fetchPosition(i).state == ISqwidMarketplace.PositionState.Auction) {
                (address[] memory addresses, uint256[] memory amounts) = fetchAuctionBids(i);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        bids[count] = AuctionBidded(fetchPosition(i), amounts[j]);
                        count++;
                        break;
                    }
                }
            }
        }

        // Set total number of pages
        totalPages = (addressBidCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns bids by an address paginated in reverse order
     * (starting from last element).
     */
    function _fetchAddressBidsReverse(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (AuctionBidded[] memory bids, uint256 totalPages) {
        // Get start and end index
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressBidCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Auction) {
                (address[] memory addresses, ) = fetchAuctionBids(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressBidCount++;
                        break;
                    }
                }
            }
        }
        if (addressBidCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (bids, 0);
        }
        if ((pageSize * (pageNumber - 1)) >= addressBidCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        uint256 startIndex = addressBidCount - (pageSize * (pageNumber - 1));
        uint256 endIndex = 1;
        if (startIndex > pageSize) {
            endIndex = startIndex - pageSize + 1;
        }
        uint256 size = startIndex - endIndex + 1;

        // Fill array
        bids = new AuctionBidded[](size);
        uint256 count;
        uint256 addressBidIndex = addressBidCount + 1;
        for (uint256 i = totalPositionCount; count < size; i--) {
            if (marketplace.fetchPosition(i).state == ISqwidMarketplace.PositionState.Auction) {
                (address[] memory addresses, uint256[] memory amounts) = fetchAuctionBids(i);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressBidIndex--;
                        if (addressBidIndex <= startIndex) {
                            bids[count] = AuctionBidded(fetchPosition(i), amounts[j]);
                            count++;
                        }
                        break;
                    }
                }
            }
        }

        // Set total number of pages
        totalPages = (addressBidCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns active raffles entered by an address paginated (starting from first element).
     */
    function _fetchAddressRaffles(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (RaffleEntered[] memory raffles, uint256 totalPages) {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressRaffleCount;
        uint256 firstMatch;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Raffle) {
                (address[] memory addresses, ) = fetchRaffleEntries(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressRaffleCount++;
                        if (addressRaffleCount == startIndex) {
                            firstMatch = i + 1;
                        }
                        break;
                    }
                }
            }
        }
        if (addressRaffleCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (raffles, 0);
        }
        if (startIndex > addressRaffleCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > addressRaffleCount) {
            endIndex = addressRaffleCount;
        }

        // Fill array
        raffles = new RaffleEntered[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = firstMatch; count < endIndex - startIndex + 1; i++) {
            if (marketplace.fetchPosition(i).state == ISqwidMarketplace.PositionState.Raffle) {
                (address[] memory addresses, uint256[] memory amounts) = fetchRaffleEntries(i);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        raffles[count] = RaffleEntered(fetchPosition(i), amounts[j]);
                        count++;
                        break;
                    }
                }
            }
        }

        // Set total number of pages
        totalPages = (addressRaffleCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns active raffles entered by an address paginated in reverse order
     * (starting from last element).
     */
    function _fetchAddressRafflesReverse(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (RaffleEntered[] memory raffles, uint256 totalPages) {
        // Get start and end index
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressRaffleCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (marketplace.fetchPosition(i + 1).state == ISqwidMarketplace.PositionState.Raffle) {
                (address[] memory addresses, ) = fetchRaffleEntries(i + 1);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressRaffleCount++;
                        break;
                    }
                }
            }
        }
        if (addressRaffleCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (raffles, 0);
        }
        if ((pageSize * (pageNumber - 1)) >= addressRaffleCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        uint256 startIndex = addressRaffleCount - (pageSize * (pageNumber - 1));
        uint256 endIndex = 1;
        if (startIndex > pageSize) {
            endIndex = startIndex - pageSize + 1;
        }
        uint256 size = startIndex - endIndex + 1;

        // Fill array
        raffles = new RaffleEntered[](size);
        uint256 count;
        uint256 addressRaffleIndex = addressRaffleCount + 1;
        for (uint256 i = totalPositionCount; count < size; i--) {
            if (marketplace.fetchPosition(i).state == ISqwidMarketplace.PositionState.Raffle) {
                (address[] memory addresses, uint256[] memory amounts) = fetchRaffleEntries(i);
                for (uint256 j; j < addresses.length; j++) {
                    if (addresses[j] == targetAddress) {
                        addressRaffleIndex--;
                        if (addressRaffleIndex <= startIndex) {
                            raffles[count] = RaffleEntered(fetchPosition(i), amounts[j]);
                            count++;
                        }
                        break;
                    }
                }
            }
        }

        // Set total number of pages
        totalPages = (addressRaffleCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns active loans funded by an address paginated (starting from first element).
     */
    function _fetchAddressLoans(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (PositionResponse[] memory loans, uint256 totalPages) {
        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressLoanCount;
        uint256 firstMatch;

        for (uint256 i; i < totalPositionCount; i++) {
            if (
                marketplace.fetchLoanData(i + 1).lender == targetAddress &&
                marketplace.fetchPosition(i + 1).positionId > 0
            ) {
                addressLoanCount++;
                if (addressLoanCount == startIndex) {
                    firstMatch = i + 1;
                }
            }
        }
        if (addressLoanCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (loans, 0);
        }
        if (startIndex > addressLoanCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > addressLoanCount) {
            endIndex = addressLoanCount;
        }

        // Fill array
        loans = new PositionResponse[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = firstMatch; count < endIndex - startIndex + 1; i++) {
            if (
                marketplace.fetchLoanData(i).lender == targetAddress &&
                marketplace.fetchPosition(i).positionId > 0
            ) {
                loans[count] = fetchPosition(i);
                count++;
            }
        }

        // Set total number of pages
        totalPages = (addressLoanCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns active loans funded by an address paginated in reverse order
     * (starting from last element).
     */
    function _fetchAddressLoansReverse(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) private view returns (PositionResponse[] memory loans, uint256 totalPages) {
        // Get start and end index
        uint256 totalPositionCount = marketplace.currentPositionId();
        uint256 addressLoanCount;
        for (uint256 i; i < totalPositionCount; i++) {
            if (
                marketplace.fetchLoanData(i + 1).lender == targetAddress &&
                marketplace.fetchPosition(i + 1).positionId > 0
            ) {
                addressLoanCount++;
            }
        }
        if (addressLoanCount == 0) {
            if (pageNumber > 1) {
                revert("SqwidMarketUtil: Invalid page number");
            }
            return (loans, 0);
        }
        if ((pageSize * (pageNumber - 1)) >= addressLoanCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        uint256 startIndex = addressLoanCount - (pageSize * (pageNumber - 1));
        uint256 endIndex = 1;
        if (startIndex > pageSize) {
            endIndex = startIndex - pageSize + 1;
        }
        uint256 size = startIndex - endIndex + 1;

        // Fill array
        loans = new PositionResponse[](size);
        uint256 count;
        uint256 addressLoanIndex = addressLoanCount + 1;
        for (uint256 i = totalPositionCount; count < size; i--) {
            if (
                marketplace.fetchLoanData(i).lender == targetAddress &&
                marketplace.fetchPosition(i).positionId > 0
            ) {
                addressLoanIndex--;
                if (addressLoanIndex <= startIndex) {
                    loans[count] = fetchPosition(i);
                    count++;
                }
            }
        }

        // Set total number of pages
        totalPages = (addressLoanCount + pageSize - 1) / pageSize;
    }

    /**
     * Returns whether a certain id is set to true (exists) by checking the byte
     * byte of its corresponding position inside the packedBooleans variable.
     */
    function _checkExistsBytes(uint256 _id, bytes memory _packedBooleans)
        private
        pure
        returns (bool)
    {
        if (_id >= _packedBooleans.length * 8) {
            return false;
        }
        uint8 b = uint8(_packedBooleans[_id / 8]);
        uint8 mask = uint8((1 << (_id % 8)));
        uint8 flag = b & mask;
        return (flag != 0);
    }
}
