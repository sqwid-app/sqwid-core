const { expect, assert } = require("chai");
const { ethers } = require("ethers");
const { getMainContracts, throwsException } = require("./util");

describe("************ Migration ******************", () => {
    let currItemId, utilContractV2Address;

    before(async () => {
        utilContractV2Address = "0xec2C914CA9601681d145DAdEcc8597A8B5561934";

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

        // Deploy marketplace v2 contract
        console.log("\tdeploying Marketplace V2 contract...");
        const MarketV2 = await reef.getContractFactory("MarketMigrationSample", owner);
        marketV2 = await MarketV2.deploy(marketFee, nft.address, market.address);
        await marketV2.deployed();
        console.log(`\tMarketV2 contact deployed at ${marketV2.address}`);

        // Deploy or get existing SqwidMarketplaceUtil for v2 contract
        const MarketUtilV2 = await reef.getContractFactory("SqwidMarketplaceUtil", owner);
        if (!utilContractV2Address || utilContractV2Address == "") {
            // Deploy SqwidMarketplaceUtil for v2 contract
            console.log("\tdeploying Util v2 contract...");
            marketUtilV2 = await MarketUtilV2.deploy(marketV2.address);
            await marketUtilV2.deployed();
        } else {
            // Get deployed contract
            marketUtilV2 = await MarketUtilV2.attach(utilContractV2Address);
            await marketUtilV2.setMarketContractAddress(marketV2.address);
        }
        console.log(`\tUtil contract v2 deployed in ${marketUtilV2.address}`);

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
        itemId = receipt1.events[2].args.itemId.toNumber();
        tokenId = receipt1.events[2].args.tokenId.toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Puts item on sale
        console.log("\tputting market item on sale...");
        const tx2 = await market.connect(seller).putItemOnSale(itemId, 1, salePrice);
        const receipt2 = await tx2.wait();
        positionId = receipt2.events[1].args[0].toNumber();
        console.log(`\tPosition created with id ${positionId}`);
    });

    it("Should migrate counters", async () => {
        currItemId = Number(await market.currentItemId());
        const currPositionId = Number(await market.currentPositionId());
        await marketV2.setCounters(currItemId, currPositionId);
        expect(Number(await marketV2.currentItemId())).to.equal(currItemId);
        expect(Number(await marketV2.currentPositionId())).to.equal(currPositionId);
    });

    it("Should migrate items", async () => {
        const totalItems = Number(await marketUtil.fetchNumberItems());
        console.log(`Migrating ${totalItems} items.`);

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
            await marketV2.setItems(submitItems);
            console.log(`\tItems migrated.`);
        } while (itemsTotalPages >= itemsPage);

        itemsTotalPages = 0;
        itemsPage = 1;
        const itemsNew = [];
        do {
            [items, totalPages] = await marketUtilV2.fetchItemsPage(itemsPerPage, itemsPage);
            itemsNew.push(...items);
            itemsTotalPages = Number(totalPages);
            itemsPage++;
        } while (itemsTotalPages >= itemsPage);

        expect(itemsOld.length).to.equal(itemsNew.length);
        expect(currItemId).to.equal(totalItems);

        for (let i = 0; i < itemsOld.length; i++) {
            const itemOld = itemsOld[i];
            const itemNew = itemsNew[i];
            expect(Number(itemNew.itemId)).to.equal(Number(itemOld.itemId));
            expect(itemNew.nftContract).to.equal(itemOld.nftContract);
            expect(Number(itemNew.tokenId)).to.equal(Number(itemOld.tokenId));
            expect(itemNew.creator).to.equal(itemOld.creator);
            expect(Number(itemNew.positionCount)).to.equal(Number(itemOld.positionCount));
            expect(itemNew.sales ? itemNew.sales.length : 0).to.equal(
                itemOld.sales ? itemOld.sales.length : 0
            );
            itemOld.sales.forEach((saleOld, index) => {
                expect(saleOld.seller).to.equal(itemNew.sales[index].seller);
                expect(saleOld.buyer).to.equal(itemNew.sales[index].buyer);
                expect(Number(saleOld.price)).to.equal(Number(itemNew.sales[index].price));
                expect(Number(saleOld.amount)).to.equal(Number(itemNew.sales[index].amount));
            });
            assert(await marketV2.registeredTokens(itemOld.nftContract, itemOld.tokenId));
        }
    });

    it("Should migrate available positions", async () => {
        const totalAvailPos = Number(await market.fetchStateCount(0));
        console.log(`Migrating ${totalAvailPos} positions`);

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
            await marketV2.setPositions(submitPositions);
            console.log(`\tPositions migrated.`);
        } while (avilPosTotalPages >= avilPosPage);

        const availPosNew = [];
        avilPosPage = 1;
        avilPosTotalPages = 0;
        do {
            [positions, totalPages] = await marketUtilV2.fetchPositionsByStatePage(
                0,
                positionsPerPage,
                avilPosPage
            );
            availPosNew.push(...positions);
            avilPosTotalPages = Number(totalPages);
            avilPosPage++;
        } while (avilPosTotalPages >= avilPosPage);

        expect(availPosOld.length).to.equal(availPosNew.length);

        for (let i = 0; i < availPosOld.length; i++) {
            const positionOld = availPosOld[i];
            const positionNew = availPosNew[i];

            expect(Number(positionNew.positionId)).to.equal(Number(positionOld.positionId));
            expect(Number(positionNew.item.itemId)).to.equal(Number(positionOld.item.itemId));
            expect(positionNew.owner).to.equal(positionOld.owner);
            expect(Number(positionNew.amount)).to.equal(Number(positionOld.amount));
            expect(Number(positionNew.price)).to.equal(Number(positionOld.price));
            expect(Number(positionNew.marketFee)).to.equal(Number(positionOld.marketFee));
            expect(positionNew.state).to.equal(positionOld.state);
            expect(
                Number(
                    await marketV2.itemAvailablePositions(
                        positionOld.item.itemId,
                        positionOld.owner
                    )
                )
            ).to.equal(Number(positionOld.positionId));
        }
    });

    it("Should update closures in the old contract", async () => {
        // Add migration address to market contract
        await market.connect(owner).setMigratorAddress(marketV2.address);

        // Buy NFT
        console.log("\tbuyer1 buying NFT from seller...");
        const tx = await market.connect(buyer).createSale(positionId, 1, { value: salePrice });
        const receipt = await tx.wait();
        const updatedPositionId = receipt.events[4].args.positionId;
        console.log("\tNFT bought");

        // Get sales from marketV2 contract
        const item = await marketV2.connect(owner).fetchItem(itemId);
        const lastSale = item.sales.at(-1);

        // Get updated position
        const updatedPositionOld = await market.fetchPosition(updatedPositionId);
        const updatedPositionNew = await marketV2.fetchPosition(updatedPositionId);

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
