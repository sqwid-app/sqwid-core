// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ISqwidMarketplace.sol";
import "./interface/ISqwidERC1155.sol";

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
     * Returns total number of items.
     */
    function fetchNumberItems() public view returns (uint256) {
        uint256 totalItemCount = marketplace.currentItemId();
        return totalItemCount;
    }

    /**
     * Returns items with all its positions paginated.
     */
    function fetchItems(uint256 pageSize, uint256 pageNumber)
        external
        view
        returns (ItemResponse[] memory items, uint256 totalPages)
    {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 25 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalItemCount = marketplace.currentItemId();
        if (totalItemCount == 0) {
            return (items, 0);
        }
        if (startIndex > totalItemCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > totalItemCount) {
            endIndex = totalItemCount;
        }

        // Fill array
        items = new ItemResponse[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = startIndex; i <= endIndex; i++) {
            items[count] = fetchItem(i);
            count++;
        }

        // Set total number pages
        totalPages = (totalItemCount + pageSize - 1) / pageSize;
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

    /**
     * Returns items created by an address with its positions paginated.
     */
    function fetchAddressItemsCreated(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (ItemResponse[] memory items, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 25 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalItemCount = marketplace.currentItemId();
        uint256 createdItemCount;
        uint256 firstMatch;
        for (uint256 i; i < totalItemCount; i++) {
            if (marketplace.fetchItem(i + 1).creator == targetAddress) {
                createdItemCount++;
                if (createdItemCount == startIndex) {
                    firstMatch = i + 1;
                }
            }
        }
        if (createdItemCount == 0) {
            return (items, 0);
        }
        if (startIndex > createdItemCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > createdItemCount) {
            endIndex = createdItemCount;
        }

        // Fill array
        items = new ItemResponse[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = firstMatch; count < endIndex - startIndex + 1; i++) {
            if (marketplace.fetchItem(i).creator == targetAddress) {
                items[count] = fetchItem(i);
                count++;
            }
        }

        // Set total number of pages
        totalPages = (createdItemCount + pageSize - 1) / pageSize;
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

    /**
     * Returns items positions from an address.
     */
    function fetchAddressPositions(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

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
            return (positions, 0);
        }
        if (startIndex > addressPositionCount) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > addressPositionCount) {
            endIndex = addressPositionCount;
        }

        // Fill array
        positions = new PositionResponse[](endIndex - startIndex + 1);
        uint256 count;
        for (uint256 i = firstMatch; count < endIndex - startIndex + 1; i++) {
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
     * Returns number of item positions for a given state.
     */
    function fetchNumberPositionsByState(ISqwidMarketplace.PositionState state)
        external
        view
        returns (uint256)
    {
        return marketplace.fetchStateCount(state);
    }

    /**
     * Returns item positions for a given state.
     */
    function fetchPositionsByState(
        ISqwidMarketplace.PositionState state,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (PositionResponse[] memory positions, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

        // Get start and end index
        uint256 startIndex = pageSize * (pageNumber - 1) + 1;
        uint256 endIndex = startIndex + pageSize - 1;
        uint256 totalStatePositions = marketplace.fetchStateCount(state);
        if (totalStatePositions == 0) {
            return (positions, 0);
        }
        if (startIndex > totalStatePositions) {
            revert("SqwidMarketUtil: Invalid page number");
        }
        if (endIndex > totalStatePositions) {
            endIndex = totalStatePositions;
        }

        // Fill array
        positions = new PositionResponse[](endIndex - startIndex + 1);
        uint256 statePositionCount;
        for (uint256 i = startIndex; statePositionCount < endIndex - startIndex + 1; i++) {
            ISqwidMarketplace.Position memory position = marketplace.fetchPosition(i);
            if (position.positionId > 0 && position.state == state) {
                if (statePositionCount + 1 >= startIndex) {
                    positions[statePositionCount] = fetchPosition(i);
                }
                statePositionCount++;
            }
        }

        // Set total number pages
        totalPages = (totalStatePositions + pageSize - 1) / pageSize;
    }

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

    /**
     * Returns bids by an address.
     */
    function fetchAddressBids(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (AuctionBidded[] memory bids, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

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

    /**
     * Returns active raffles entered by an address.
     */
    function fetchAddressRaffles(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (RaffleEntered[] memory raffles, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

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
     * Returns number active loans funded by an address.
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

    /**
     * Returns active loans funded by an address.
     */
    function fetchAddressLoans(
        address targetAddress,
        uint256 pageSize,
        uint256 pageNumber
    ) external view returns (PositionResponse[] memory loans, uint256 totalPages) {
        require(pageNumber > 0, "SqwidMarketUtil: Page number cannot be 0");
        require(pageSize <= 100 && pageSize > 0, "SqwidMarketUtil: Invalid page size");

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
