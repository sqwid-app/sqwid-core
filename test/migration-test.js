const { expect, assert } = require("chai");

describe("************ Migration ******************", () => {
    let marketContractAddress, market, owner, migration;

    before(async () => {
        marketContractAddress = config.contracts.market;

        if (!marketContractAddress || marketContractAddress == "") {
            assert.fail("Market contract has to be deployed and contain data to run this test.");
        }

        owner = await reef.getSignerByName("account1");

        const Market = await reef.getContractFactory("SqwidMarketplace", owner);
        market = await Market.attach(marketContractAddress);

        console.log("\tdeploying migration contract...");
        let Migration = await reef.getContractFactory("MarketMigrationSample", owner);
        migration = await Migration.deploy(marketContractAddress);
        await migration.deployed();
        console.log(`\tMigration contact deployed ${migration.address}`);
    });

    it("Should migrate data to new market contact", async () => {
        const itemsOld = await market.fetchAllItems();
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

        const availablePositions = await market.fetchPositionsByState(0);
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

        const onSale = await market.fetchPositionsByState(1);
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

        const auctions = await market.fetchPositionsByState(2);
        auctions.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const auctionData = await migration.idToAuctionData(positionOld.positionId);
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
        });

        const raffles = await market.fetchPositionsByState(3);
        raffles.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const raffleData = await migration.idToRaffleData(positionOld.positionId);
            const [raffleAddrOld, raffleAmountsOld] = await market.fetchRaffleAmounts(
                positionOld.positionId
            );
            const [raffleAddrNew, raffleAmountsNew] = await migration.fetchRaffleAmounts(
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

        const loans = await market.fetchPositionsByState(4);
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
});
