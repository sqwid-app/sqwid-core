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
        console.log("\tSetting migration counters.");
        const currItemId = Number(await market.currentItemId());
        const currPositionId = Number(await market.currentPositionId());
        await migration.setCounters(currItemId, currPositionId);
        expect(Number(await migration.itemIds())).to.equal(currItemId);
        expect(Number(await migration.positionIds())).to.equal(currPositionId);

        const totalItems = Number(await marketUtil.fetchNumberItems());
        console.log(`***** Migrating ${totalItems} items *****`);

        const itemsOld = [];
        let itemsPage = 1;
        let itemsTotalPages = 0;
        const itemsPerPage = 100;
        do {
            [items, totalPages] = await marketUtil.fetchItemsPage(itemsPerPage, itemsPage);
            itemsOld.push(...items);
            const submitItems = items.map((item) => {
                return [
                    item.itemId,
                    item.nftContract,
                    item.tokenId,
                    item.creator,
                    item.positionCount,
                    item.sales,
                ];
            });
            itemsTotalPages = Number(totalPages);
            const ini = (itemsPage - 1) * itemsPerPage + 1;
            const end = ini + items.length - 1;
            itemsPage++;
            console.log(`\tadding items ${ini} to ${end}...`);
            await migration.setItems(submitItems);
            console.log(`\tItems migrated.`);
        } while (itemsTotalPages >= itemsPage);

        expect(itemsOld.length).to.equal(totalItems);
        expect(currItemId).to.equal(totalItems);

        itemsOld.forEach(async (itemOld) => {
            const itemNew = await migration.idToItem(itemOld.itemId);
            const sales = await migration.fetchItemSales(itemOld.itemId);
            expect(Number(itemNew.itemId)).to.equal(Number(itemOld.itemId));
            expect(itemNew.nftContract).to.equal(itemOld.nftContract);
            expect(Number(itemNew.tokenId)).to.equal(Number(itemOld.tokenId));
            expect(itemNew.creator).to.equal(itemOld.creator);
            expect(Number(itemNew.positionCount)).to.equal(Number(itemOld.positionCount));
            expect(sales.length).to.equal(itemOld.sales ? itemOld.sales.length : 0);
            itemOld.sales.forEach((saleOld, index) => {
                expect(saleOld.seller).to.equal(sales[index].seller);
                expect(saleOld.buyer).to.equal(sales[index].buyer);
                expect(Number(saleOld.price)).to.equal(Number(sales[index].price));
                expect(Number(saleOld.amount)).to.equal(Number(sales[index].amount));
            });
        });

        const totalAvailPos = Number(await market.fetchStateCount(0));
        console.log(`***** Migrating ${totalAvailPos} positions *****`);

        const availPosOld = [];
        let avilPosPage = 1;
        let avilPosTotalPages = 0;
        const positionsPerPage = 100;
        do {
            [positions, totalPages] = await marketUtil.fetchPositionsByStatePage(
                0,
                positionsPerPage,
                avilPosPage
            );
            availPosOld.push(...positions);
            const submitPositions = positions.map((position) => {
                return [
                    position.positionId,
                    position.item.itemId,
                    position.owner,
                    position.amount,
                    position.price,
                    position.marketFee,
                    position.state,
                ];
            });
            avilPosTotalPages = Number(totalPages);
            const ini = (avilPosPage - 1) * positionsPerPage + 1;
            const end = ini + positions.length - 1;
            avilPosPage++;
            console.log(`\tadding positions ${ini} to ${end}...`);
            await migration.setPositions(submitPositions);
            console.log(`\tPositions migrated.`);
        } while (avilPosTotalPages >= avilPosPage);

        expect(availPosOld.length).to.equal(totalAvailPos);

        availPosOld.forEach(async (positionOld) => {
            const position = await migration.idToPosition(positionOld.positionId);
            expect(Number(position.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(position.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(position.owner).to.equal(positionOld.owner);
            expect(Number(position.amount)).to.equal(Number(positionOld.amount));
            expect(Number(position.price)).to.equal(Number(positionOld.price));
            expect(Number(position.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(position.state).to.equal(positionOld.state);
        });
    });

    it("Should update closures in the old contract", async () => {
        // Add migration address to market contract
        await market.connect(owner).setMigratorAddress(migration.address);

        // Buy NFT
        console.log("\tbuyer1 buying NFT from seller...");
        const tx = await market.connect(buyer).createSale(positionId, 1, { value: salePrice });
        const receipt = await tx.wait();
        const updatedPositionId = receipt.events[4].args.positionId;
        console.log("\tNFT bought");

        // Get sales from migration contract
        const sales = await migration.connect(owner).fetchItemSales(itemId);
        const lastSale = sales.at(-1);

        // Get updated position
        const updatedPositionOld = await market.fetchPosition(updatedPositionId);
        const updatedPositionNew = await migration.idToPosition(updatedPositionId);

        expect(lastSale.seller).to.equal(sellerAddress);
        expect(lastSale.buyer).to.equal(buyerAddress);
        expect(Number(lastSale.price)).to.equal(Number(salePrice));
        expect(Number(lastSale.amount)).to.equal(1);

        expect(Number(updatedPositionNew.positionId)).to.equal(
            Number(updatedPositionOld.positionId)
        );
        expect(Number(updatedPositionNew.itemId)).to.equal(Number(updatedPositionOld.itemId));
        expect(updatedPositionNew.owner).to.equal(updatedPositionOld.owner);
        expect(Number(updatedPositionNew.amount)).to.equal(Number(updatedPositionOld.amount));
        expect(Number(updatedPositionNew.price)).to.equal(Number(updatedPositionOld.price));
        expect(Number(updatedPositionNew.marketFee)).to.equal(Number(updatedPositionOld.marketFee));
        expect(Number(updatedPositionNew.state)).to.equal(Number(updatedPositionOld.state));
    });

    it("Should not put item on sale after migration", async () => {
        console.log("\tputting market item on sale...");
        await throwsException(
            market.connect(buyer).putItemOnSale(itemId, 1, salePrice),
            "SqwidMarket: Not last market version"
        );

        await market.connect(owner).setMigratorAddress(ethers.constants.AddressZero);
    });
});
