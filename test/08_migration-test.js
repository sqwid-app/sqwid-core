const { expect } = require("chai");
const { getMainContracts, throwsException } = require("./util");

describe("************ Migration ******************", () => {
    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        seller = await reef.getSignerByName("account2");
        buyer = await reef.getSignerByName("account3");
        artist = await reef.getSignerByName("account4");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        sellerAddress = await seller.getAddress();
        buyerAddress = await buyer.getAddress();
        artistAddress = await artist.getAddress();

        // Initialize global variables
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        royaltyValue = 1000; // 10%
        marketFee = 250; // 2.5%
        salePrice = ethers.utils.parseUnits("5", "ether");

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        marketUtil = contracts.marketUtil;

        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(seller).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(seller)
            .mint(1, "https://fake-uri-1.com", "image", artistAddress, royaltyValue);
        const receipt1 = await tx1.wait();
        itemId = receipt1.events[2].args[0].toNumber();
        tokenId = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Puts item on sale
        console.log("\tputting market item on sale...");
        const tx2 = await market.connect(seller).putItemOnSale(itemId, 1, salePrice);
        const receipt2 = await tx2.wait();
        positionId = receipt2.events[1].args[0].toNumber();
        console.log(`\tPosition created with id ${positionId}`);

        // Deploy migration contract
        console.log("\tdeploying migration contract...");
        const Migration = await reef.getContractFactory("MarketMigrationSample", owner);
        migration = await Migration.deploy(market.address, marketUtil.address);
        await migration.deployed();
        console.log(`\tMigration contact deployed ${migration.address}`);
    });

    it("Should migrate existing data to new market contact", async () => {
        const itemsOld = [];
        let itemsPage = 1;
        let itemsTotalPages = 0;
        do {
            [items, totalPages] = await marketUtil.fetchItems(25, itemsPage);
            itemsOld.push(...items);
            totalPages_ = Number(itemsTotalPages);
            itemsPage++;
        } while (itemsTotalPages > itemsPage + 1);

        itemsOld.forEach(async (itemOld) => {
            const itemNew = await migration.idToItem(itemOld.itemId);
            const sales = await migration.fetchItemSales(itemOld.itemId);
            expect(Number(itemNew.itemId)).to.equal(Number(itemOld.itemId));
            expect(itemNew.nftContract).to.equal(itemOld.nftContract);
            expect(Number(itemNew.tokenId)).to.equal(Number(itemOld.tokenId));
            expect(itemNew.creator).to.equal(itemOld.creator);
            expect(Number(itemNew.positionCount)).to.equal(itemOld.positions.length);
            expect(sales.length).to.equal(itemOld.sales ? itemOld.sales.length : 0);
            itemOld.sales.forEach((saleOld, index) => {
                expect(saleOld.seller).to.equal(sales[index].seller);
                expect(saleOld.buyer).to.equal(sales[index].buyer);
                expect(Number(saleOld.price)).to.equal(Number(sales[index].price));
                expect(Number(saleOld.amount)).to.equal(Number(sales[index].amount));
            });
        });

        const availablePositions = await getAllPositionsByState(0);
        availablePositions.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
        });

        const onSale = await getAllPositionsByState(1);
        onSale.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
        });

        const auctions = await getAllPositionsByState(2);
        auctions.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const auctionData = await migration.idToAuctionData(positionOld.positionId);
            const [auctionAddrOld, auctionAmountsOld] = await marketUtil.fetchAuctionBids(
                positionOld.positionId
            );
            const [auctionAddrNew, auctionAmountsNew] = await migration.fetchAuctionBids(
                positionOld.positionId
            );
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
            expect(auctionData.deadline).to.equal(positionOld.auctionData.deadline);
            expect(Number(auctionData.minBid)).to.equal(Number(positionOld.auctionData.minBid));
            expect(auctionData.highestBidder).to.equal(positionOld.auctionData.highestBidder);
            expect(Number(auctionData.highestBid)).to.equal(
                Number(positionOld.auctionData.highestBid)
            );
            expect(auctionAddrNew.length).to.equal(auctionAddrOld.length);
            auctionAddrOld.forEach((addr, index) => {
                expect(addr).to.equal(auctionAddrNew[index]);
                expect(auctionAmountsOld[index]).to.equal(auctionAmountsNew[index]);
            });
        });

        const raffles = await getAllPositionsByState(3);
        raffles.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const raffleData = await migration.idToRaffleData(positionOld.positionId);
            const [raffleAddrOld, raffleAmountsOld] = await marketUtil.fetchRaffleEntries(
                positionOld.positionId
            );
            const [raffleAddrNew, raffleAmountsNew] = await migration.fetchRaffleEntries(
                positionOld.positionId
            );
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
            expect(raffleData.deadline).to.equal(positionOld.raffleData.deadline);
            expect(Number(raffleData.totalValue)).to.equal(
                Number(positionOld.raffleData.totalValue)
            );
            expect(raffleData.totalAddresses).to.equal(positionOld.raffleData.totalAddresses);
            expect(raffleAddrNew.length).to.equal(raffleAddrOld.length);
            raffleAddrOld.forEach((addr, index) => {
                expect(addr).to.equal(raffleAddrNew[index]);
                expect(raffleAmountsOld[index]).to.equal(raffleAmountsNew[index]);
            });
        });

        const loans = await getAllPositionsByState(4);
        loans.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const loanData = await migration.idToLoanData(positionOld.positionId);
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
            expect(Number(loanData.loanAmount)).to.equal(Number(positionOld.loanData.loanAmount));
            expect(Number(loanData.feeAmount)).to.equal(Number(positionOld.loanData.feeAmount));
            expect(Number(loanData.numMinutes)).to.equal(Number(positionOld.loanData.numMinutes));
            expect(loanData.deadline).to.equal(positionOld.loanData.deadline);
            expect(loanData.lender).to.equal(positionOld.loanData.lender);
        });
    });

    it("Should update closures in the old contract", async () => {
        // Add migration address to market contract
        await market.connect(owner).setMigratorAddress(migration.address);

        // Buy NFT
        console.log("\tbuyer1 buying NFT from seller...");
        await market.connect(buyer).createSale(positionId, 1, { value: salePrice });
        console.log("\tNFT bought");

        // Get sales from migration contract
        const sales = await migration.connect(owner).fetchItemSales(itemId);
        const lastSale = sales.at(-1);

        expect(lastSale.seller).to.equal(sellerAddress);
        expect(lastSale.buyer).to.equal(buyerAddress);
        expect(Number(lastSale.price)).to.equal(Number(salePrice));
        expect(Number(lastSale.amount)).to.equal(1);
    });

    it("Should not put item on sale after migration", async () => {
        console.log("\tputting market item on sale...");
        await throwsException(
            market.connect(buyer).putItemOnSale(itemId, 1, salePrice),
            "SqwidMarket: Not last market version"
        );

        await market.connect(owner).setMigratorAddress(ethers.constants.AddressZero);
    });

    async function getAllPositionsByState(state) {
        let page = 1;
        let _totalPages = 0;
        const totalPositions = [];
        do {
            [positions, totalPages] = await marketUtil.fetchPositionsByState(state, 100, page);
            totalPositions.push(...positions);
            _totalPages = Number(totalPages);
            page++;
        } while (_totalPages >= page);

        return totalPositions;
    }
});
