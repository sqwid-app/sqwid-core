const { expect } = require("chai");
const { getMainContracts, getBalanceHelper, getBalance, throwsException } = require("./util");

describe("************ Regular sale ******************", () => {
    let token1Id, token2Id, item1Id, item2Id, position1Id, position2Id;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        seller = await reef.getSignerByName("account2");
        buyer1 = await reef.getSignerByName("account3");
        artist = await reef.getSignerByName("account4");
        helper = await reef.getSignerByName("account5");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        sellerAddress = await seller.getAddress();
        buyer1Address = await buyer1.getAddress();
        artistAddress = await artist.getAddress();

        // Initialize global variables
        marketFee = 250; // 2.5%
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        salePrice = ethers.utils.parseUnits("50", "ether");
        royaltyValue = 1000; // 10%

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        marketUtil = contracts.marketUtil;
        balanceHelper = await getBalanceHelper();
    });

    it("Should put market item on sale", async () => {
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
        item1Id = receipt1.events[2].args[0].toNumber();
        token1Id = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${token1Id}`);
        console.log(`\tMarket item created with itemId ${item1Id}`);

        // Puts item on sale
        console.log("\tputting market item on sale...");
        const tx2 = await market.connect(seller).putItemOnSale(item1Id, 1, salePrice);
        const receipt2 = await tx2.wait();
        position1Id = receipt2.events[1].args[0].toNumber();
        console.log(`\tPosition created with id ${position1Id}`);

        // Results
        const position = await marketUtil.fetchPosition(position1Id);
        const item = await marketUtil.fetchItem(item1Id);

        // Evaluate results
        expect(Number(position.positionId)).to.equal(position1Id);
        expect(Number(position.item.itemId)).to.equal(item1Id);
        expect(position.owner).to.equal(sellerAddress);
        expect(Number(position.amount)).to.equal(1);
        expect(Number(position.price)).to.equal(Number(salePrice));
        expect(Number(position.marketFee)).to.equal(Number(marketFee));
        expect(Number(position.state)).to.equal(1); // PositionState.RegularSale = 1
        expect(Number(item.positions.at(-1).positionId)).to.equal(position1Id);
    });

    it("Should put new nft on sale", async () => {
        // Initial data
        const iniPositionsOnRegSale = await marketUtil.fetchPositionsByState(1);
        const iniItems = await marketUtil.fetchAllItems();

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(seller)
            .mint(10, "https://fake-uri-1.com", "image", artistAddress, royaltyValue);
        const receipt1 = await tx1.wait();
        item2Id = receipt1.events[2].args[0].toNumber();
        token2Id = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${token2Id}`);
        console.log(`\tMarket item created with itemId ${item2Id}`);

        // Puts item on sale
        console.log("\tputting market item on sale...");
        const tx2 = await market.connect(seller).putItemOnSale(item2Id, 10, salePrice);
        const receipt2 = await tx2.wait();
        position2Id = receipt2.events[1].args[0].toNumber();
        console.log(`\tPosition created with id ${position2Id}`);

        // Results
        const position = await marketUtil.fetchPosition(position2Id);
        const item = await marketUtil.fetchItem(item2Id);
        const endPositionsOnRegSale = await marketUtil.fetchPositionsByState(1);
        const endItems = await marketUtil.fetchAllItems();

        // Evaluate results
        expect(Number(position.positionId)).to.equal(position2Id);
        expect(Number(position.item.itemId)).to.equal(item2Id);
        expect(endItems.length - iniItems.length).to.equal(1);
        expect(Number(endItems.at(-1).itemId)).to.equal(item2Id);
        expect(position.owner).to.equal(sellerAddress);
        expect(Number(position.amount)).to.equal(10);
        expect(Number(position.price)).to.equal(Number(salePrice));
        expect(Number(position.marketFee)).to.equal(Number(marketFee));
        expect(Number(position.state)).to.equal(1); // RegularSale = 1
        expect(Number(item.positions.at(-1).positionId)).to.equal(position2Id);
        expect(endPositionsOnRegSale.length - iniPositionsOnRegSale.length).to.equal(1);
        expect(Number(endPositionsOnRegSale.at(-1).positionId)).to.equal(position2Id);
    });

    it("Should create sale", async () => {
        // Initial data
        const iniSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const iniArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniBuyer1TokenAmount = await nft.balanceOf(buyer1Address, token1Id);
        const iniAvailablePositions = await marketUtil.fetchPositionsByState(0);

        // Buy NFT
        console.log("\tbuyer1 buying NFT from seller...");
        await market.connect(buyer1).createSale(position1Id, 1, { value: salePrice });
        console.log("\tNFT bought");

        // Final data
        const endSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endBuyer1TokenAmount = await nft.balanceOf(buyer1Address, token1Id);
        const royaltiesAmountRaw = (salePrice * royaltyValue) / 10000;
        const royaltiesAmount = ethers.utils.parseUnits(royaltiesAmountRaw.toString(), "wei");
        const marketFeeAmountRaw = ((salePrice - royaltiesAmount) * marketFee) / 10000;
        const marketFeeAmount = ethers.utils.parseUnits(marketFeeAmountRaw.toString(), "wei");
        const item = await marketUtil.fetchItem(item1Id);
        const endAvailablePositions = await marketUtil.fetchPositionsByState(0);

        // Evaluate results
        expect(endBuyer1TokenAmount - iniBuyer1TokenAmount).to.equal(1);
        expect(Number(endBuyer1Balance))
            .to.lte(Number(iniBuyer1Balance.sub(salePrice)))
            .gt(Number(iniBuyer1Balance.sub(salePrice).sub(maxGasFee)));
        expect(Number(endArtistBalance)).to.equal(Number(iniArtistBalance.add(royaltiesAmount)));

        expect(Number(endOwnerMarketBalance)).to.equal(
            Number(iniOwnerMarketBalance.add(marketFeeAmount))
        );
        expect(Number(endSellerBalance)).to.equal(
            Number(iniSellerBalance.add(salePrice).sub(royaltiesAmount).sub(marketFeeAmount))
        );

        expect(item.nftContract).to.equal(nft.address);
        expect(Number(item.tokenId)).to.equal(token1Id);
        expect(item.sales[0].seller).to.equal(sellerAddress);
        expect(item.sales[0].buyer).to.equal(buyer1Address);
        expect(Number(item.sales[0].price)).to.equal(Number(salePrice));
        expect(endAvailablePositions.length - iniAvailablePositions.length).to.equal(1);
    });

    it("Should allow market owner to withdraw fees", async () => {
        const iniOwnerBalance = await getBalance(balanceHelper, ownerAddress, "owner");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        console.log("\towner withdrawing balance...");
        await market.connect(owner).withdraw();
        console.log("\tWithdrawing completed.");
        const endOwnerBalance = await getBalance(balanceHelper, ownerAddress, "owner");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");

        expect(Number(iniOwnerMarketBalance)).to.equal(
            Number(iniMarketBalance.sub(endMarketBalance))
        );
        expect(Number(iniOwnerMarketBalance))
            .to.gte(Number(endOwnerBalance.sub(iniOwnerBalance)))
            .to.lt(Number(endOwnerBalance.sub(iniOwnerBalance).add(maxGasFee)));
        expect(Number(endOwnerMarketBalance)).to.equal(0);
    });

    it("Should allow to end sale only to seller", async () => {
        // Initial data
        const iniTokenBalance = await nft.balanceOf(sellerAddress, token2Id);
        const iniItem = await marketUtil.fetchItem(item2Id);
        const iniOnsale = iniItem.positions.filter((pos) => pos.state == 1).length;

        // End sale by buyer1
        console.log("\tbuyer1 ending sale...");
        await throwsException(
            market.connect(buyer1).unlistPositionOnSale(position2Id),
            "SqwidMarket: Only seller can unlist item"
        );

        // End sale by seller
        console.log("\tseller ending sale...");
        await market.connect(seller).unlistPositionOnSale(position2Id);
        console.log("\tsale ended.");

        // Final data
        const endTokenBalance = await nft.balanceOf(sellerAddress, token2Id);
        const endItem = await marketUtil.fetchItem(item2Id);
        const endOnsale = endItem.positions.filter((pos) => pos.state == 1).length;

        // Evaluate results
        expect(endTokenBalance - iniTokenBalance).to.equal(10);
        expect(iniOnsale - endOnsale).to.equal(1);
    });
});
