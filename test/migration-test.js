const { expect, assert } = require("chai");

describe("************ Migration ******************", () => {
    let marketContractAddress;

    before(async () => {
        marketContractAddress = config.contracts.market;

        if (!marketContractAddress || marketContractAddress == "") {
            assert.fail("Market contract has to be deployed and contain data to run this test.");
        }
    });

    it("Should migrate data to new market contact", async () => {
        owner = await reef.getSignerByName("account1");

        console.log("\tdeploying new market contract...");
        let Migration = await hre.ethers.getContractFactory("MarketMigrationSample", owner);
        console.log("one");
        const migration = await Migration.deploy(marketContractAddress);
        onsole.log("two");
        await migration.deployed();
        console.log(`\tMigration contract deployed: ${migration.address}`);

        const itemsOld = await market.fetchAllItems();
        itemsOld.forEach(async (itemOld) => {
            const itemNew = await migration.idToItem(itemOld.itemId);
            const sales = await migration.fetchItemSales(itemOld.itemId);
            expect(itemNew.itemId).to.equal(itemOld.itemId);
            expect(itemNew.nftContract).to.equal(itemOld.nftContract);
            expect(itemNew.tokenId).to.equal(itemOld.tokenId);
            expect(itemNew.creator).to.equal(itemOld.creator);
            expect(itemNew.positionCount).to.equal(itemOld.positions.length);
            expect(sales.length).to.equal(itemOld.sales ? itemOld.sales.length : 0);
            itemOld.sales.forEach((saleOld, index) => {
                expect(saleOld.seller).to.equal(sales[index].seller);
                expect(saleOld.buyer).to.equal(sales[index].buyer);
                expect(saleOld.price).to.equal(sales[index].price);
                expect(saleOld.amount).to.equal(sales[index].amount);
            });
        });

        const availablePositions = await market.fetchAllAvailablePositions();
        availablePositions.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            expect(position.positionId).to.equal(positionOld.positionId);
            expect(position.itemId).to.equal(positionOld.item.itemId);
            expect(position.owner).to.equal(positionOld.owner);
            expect(position.amount).to.equal(positionOld.amount);
            expect(position.price).to.equal(positionOld.price);
            expect(position.marketFee).to.equal(positionOld.marketFee);
            expect(position.state).to.equal(positionOld.state);
        });

        const onSale = await market.fetchPositionsByState(1);
        onSale.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            expect(position.positionId).to.equal(positionOld.positionId);
            expect(position.itemId).to.equal(positionOld.item.itemId);
            expect(position.owner).to.equal(positionOld.owner);
            expect(position.amount).to.equal(positionOld.amount);
            expect(position.price).to.equal(positionOld.price);
            expect(position.marketFee).to.equal(positionOld.marketFee);
            expect(position.state).to.equal(positionOld.state);
        });

        const auctions = await market.fetchPositionsByState(2);
        auctions.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const auctionData = await migration.idToAuctionData(positionOld.positionId);
            expect(position.positionId).to.equal(positionOld.positionId);
            expect(position.itemId).to.equal(positionOld.item.itemId);
            expect(position.owner).to.equal(positionOld.owner);
            expect(position.amount).to.equal(positionOld.amount);
            expect(position.price).to.equal(positionOld.price);
            expect(position.marketFee).to.equal(positionOld.marketFee);
            expect(position.state).to.equal(positionOld.state);
            expect(auctionData.deadline).to.equal(positionOld.auctionData.deadline);
            expect(auctionData.minBid).to.equal(positionOld.auctionData.minBid);
            expect(auctionData.highestBidder).to.equal(positionOld.auctionData.highestBidder);
            expect(auctionData.highestBid).to.equal(positionOld.auctionData.highestBid);
        });

        const raffles = await market.fetchPositionsByState(3);
        raffles.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const raffleData = await migration.idToRaffleData(positionOld.positionId);
            // const [raffleAddrOld, raffleAmountsOld] = await market.fetchRaffleAmounts(
            //     positionOld.positionId
            // );
            // const [raffleAddrNew, raffleAmountsNew] = await migration.fetchRaffleAmounts(
            //     positionOld.positionId
            // );
            expect(position.positionId).to.equal(positionOld.positionId);
            expect(position.itemId).to.equal(positionOld.item.itemId);
            expect(position.owner).to.equal(positionOld.owner);
            expect(position.amount).to.equal(positionOld.amount);
            expect(position.price).to.equal(positionOld.price);
            expect(position.marketFee).to.equal(positionOld.marketFee);
            expect(position.state).to.equal(positionOld.state);
            expect(raffleData.deadline).to.equal(positionOld.raffleData.deadline);
            expect(raffleData.totalValue).to.equal(positionOld.raffleData.totalValue);
            expect(raffleData.totalAddresses).to.equal(positionOld.raffleData.totalAddresses);
            expect(raffleAddrNew.length).to.equal(raffleAddrOld.length);
            // TODO
            // raffleAddrOld.forEach((addr, index) => {
            //     expect(addr).to.equal(raffleAddrNew[index]);
            //     expect(raffleAmountsOld[index]).to.equal(raffleAmountsNew[index]);
            // });
        });

        const loans = await market.fetchPositionsByState(4);
        loans.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            const loanData = await migration.idToLoanData(positionOld.positionId);
            expect(position.positionId).to.equal(positionOld.positionId);
            expect(position.itemId).to.equal(positionOld.item.itemId);
            expect(position.owner).to.equal(positionOld.owner);
            expect(position.amount).to.equal(positionOld.amount);
            expect(position.price).to.equal(positionOld.price);
            expect(position.marketFee).to.equal(positionOld.marketFee);
            expect(position.state).to.equal(positionOld.state);
            expect(loanData.loanAmount).to.equal(positionOld.loanData.loanAmount);
            expect(loanData.feeAmount).to.equal(positionOld.loanData.feeAmount);
            expect(loanData.numMinutes).to.equal(positionOld.loanData.numMinutes);
            expect(loanData.deadline).to.equal(positionOld.loanData.deadline);
            expect(loanData.lender).to.equal(positionOld.loanData.lender);
        });
    });
});
