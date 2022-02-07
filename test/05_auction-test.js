const { expect } = require("chai");
const {
    getMainContracts,
    getBalanceHelper,
    formatBigNumber,
    getBalance,
    throwsException,
    delay,
} = require("./util");

describe("************ Auctions ******************", () => {
    let market,
        nft,
        balanceHelper,
        owner,
        seller,
        artist,
        buyer1,
        buyer2,
        marketFee,
        ownerAddress,
        sellerAddress,
        artistAddress,
        buyer1Address,
        buyer2Address,
        deadline,
        tokenId,
        itemId,
        auctionId,
        royaltyValue,
        maxGasFee,
        numMinutes,
        minBid,
        tokensAmount,
        bid1Amount,
        bid2Amount,
        bid3Amount,
        bid4Amount;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        seller = await reef.getSignerByName("account2");
        buyer1 = await reef.getSignerByName("account3");
        buyer2 = await reef.getSignerByName("account4");
        artist = await reef.getSignerByName("account5");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        sellerAddress = await seller.getAddress();
        buyer1Address = await buyer1.getAddress();
        buyer2Address = await buyer2.getAddress();
        artistAddress = await artist.getAddress();

        // Initialize global variables
        marketFee = 250; // 2.5%
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        numMinutes = 11;
        minBid = ethers.utils.parseUnits("50", "ether");
        tokensAmount = 8;
        bid1Amount = ethers.utils.parseUnits("49", "ether");
        bid2Amount = ethers.utils.parseUnits("60", "ether");
        bid3Amount = ethers.utils.parseUnits("1", "ether");
        bid4Amount = ethers.utils.parseUnits("62", "ether");
        royaltyValue = 1000; // 10%

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        balanceHelper = await getBalanceHelper();
    });

    it("Should create auction", async () => {
        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(seller).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Initial data
        const iniAuctions = await market.fetchPositionsByState(2);

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(seller)
            .mint(tokensAmount, "https://fake-uri.com", artistAddress, royaltyValue);
        const receipt1 = await tx1.wait();
        itemId = receipt1.events[2].args[0].toNumber();
        tokenId = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Create auction
        console.log("\tseller creating auction...");
        await market.connect(seller).createItemAuction(itemId, tokensAmount, numMinutes, minBid);
        console.log("\tauction created.");

        // Final data
        const endAuctions = await market.fetchPositionsByState(2);
        const auction = endAuctions.at(-1);
        auctionId = auction.positionId;
        const tokenUri = await nft.uri(tokenId);
        deadline = new Date(auction.auctionData.deadline * 1000);

        // Evaluate results
        expect(endAuctions.length).to.equal(iniAuctions.length + 1);
        expect(tokenUri).to.equal("https://fake-uri.com");
        expect(auction.item.nftContract).to.equal(nft.address);
        expect(Number(auction.item.tokenId)).to.equal(tokenId);
        expect(auction.owner).to.equal(sellerAddress);
        expect(Number(auction.amount)).to.equal(tokensAmount);
        expect(auction.state).to.equal(2); // PositionState.Auction = 2
        expect(deadline)
            .to.lt(new Date(new Date().getTime() + 1000 * 60 * (numMinutes + 1)))
            .gt(new Date());
        expect(formatBigNumber(auction.auctionData.minBid)).equals(formatBigNumber(minBid));
        expect(Number(auction.marketFee)).to.equal(Number(marketFee));
    });

    it("Should not allow bids lower than minimum bid", async () => {
        console.log("\tbuyer1 creating bid...");
        await throwsException(
            market.connect(buyer1).createBid(auctionId, { value: bid1Amount }),
            "SqwidMarket: Bid value invalid"
        );
    });

    it("Should create bid", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        // Creates bid
        console.log("\tbuyer1 creating bid...");
        await market.connect(buyer1).createBid(auctionId, { value: bid2Amount });
        console.log("\tbid created");

        // Final data
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);

        // Evaluate results
        expect(deadline.getTime()).equals(oldDeadline.getTime());
        expect(formatBigNumber(auctionData.highestBid)).equals(formatBigNumber(bid2Amount));
        expect(auctionData.highestBidder).equals(buyer1Address);
        expect(endBuyer1Balance)
            .to.lte(iniBuyer1Balance - formatBigNumber(bid2Amount))
            .gt(iniBuyer1Balance - formatBigNumber(bid2Amount) - formatBigNumber(maxGasFee));
        expect(endMarketBalance)
            .to.gte(iniMarketBalance + formatBigNumber(bid2Amount))
            .lt(iniMarketBalance + formatBigNumber(bid2Amount) + 1);
    });

    it("Should not allow bids equal or lower than highest bid", async () => {
        console.log("\tbuyer2 creating bid...");
        await throwsException(
            market.connect(buyer2).createBid(auctionId, { value: bid2Amount }),
            "SqwidMarket: Bid value invalid"
        );
    });

    it("Should increase bid", async () => {
        // Creates bid
        console.log("\tbuyer1 creating bid...");
        await market.connect(buyer1).createBid(auctionId, { value: bid3Amount });
        console.log("\tbid created");

        // Final data
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);

        // Evaluate results
        expect(deadline.getTime()).equals(oldDeadline.getTime());
        expect(formatBigNumber(auctionData.highestBid)).equals(
            formatBigNumber(bid2Amount.add(bid3Amount))
        );
        expect(auctionData.highestBidder).equals(buyer1Address);
    });

    it("Should extend auction deadline", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const iniBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        // Wait until 10 minutes before deadline
        const timeUntilDeadline = deadline - new Date();
        console.log(`\ttime until deadline: ${timeUntilDeadline / 60000} mins.`);
        if (timeUntilDeadline > 600000) {
            const timeToWait = timeUntilDeadline - 590000;
            console.log(`\twaiting for ${timeToWait / 1000} seconds...`);
            await delay(timeToWait);
            console.log("\t10 minutes for deadline.");
        }

        // Creates bid
        console.log("\tbuyer2 creating bid...");
        await market.connect(buyer2).createBid(auctionId, { value: bid4Amount });
        console.log("\tbid created");

        // Final data
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);
        console.log(`\tdeadline extended by ${(deadline - oldDeadline) / 1000} secs.`);
        const bidIncrease =
            formatBigNumber(bid4Amount) - formatBigNumber(bid2Amount) - formatBigNumber(bid3Amount);

        // Evaluate results
        expect(deadline.getTime()).gt(oldDeadline.getTime());
        expect(formatBigNumber(auctionData.highestBid)).equals(formatBigNumber(bid4Amount));
        expect(auctionData.highestBidder).equals(buyer2Address);
        expect(endBuyer1Balance).to.equals(
            iniBuyer1Balance + formatBigNumber(bid2Amount) + formatBigNumber(bid3Amount)
        );
        expect(endBuyer2Balance)
            .to.lte(iniBuyer2Balance - formatBigNumber(bid4Amount))
            .gt(iniBuyer2Balance - formatBigNumber(bid4Amount) - formatBigNumber(maxGasFee));
        expect(endMarketBalance)
            .to.gte(iniMarketBalance + bidIncrease)
            .lt(iniMarketBalance + bidIncrease + 1);
    });

    it.skip("Should end auction with bids", async () => {
        // Initial data
        const iniSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const iniArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");
        await getBalance(balanceHelper, buyer1Address, "buyer1");
        const auctions = await market.fetchPositionsByState(2);
        const iniNumAuctions = auctions.length;
        const auction = auctions.at(-1);
        itemId = auction.item.itemId;
        if (!auctionId) {
            // Set data if test has not been run directly after the other ones
            auctionId = Number(auction.positionId);
            tokenId = auction.item.tokenId;
            deadline = new Date(auction.auctionData.deadline * 1000);
        }
        const iniBuyer2TokenAmount = await nft.balanceOf(buyer2Address, tokenId);

        // Wait until deadline
        const timeUntilDeadline = deadline - new Date();
        console.log(`\ttime until deadline: ${timeUntilDeadline / 60000} mins.`);
        if (timeUntilDeadline > 0) {
            console.log("\twaiting for deadline...");
            await delay(timeUntilDeadline + 15000);
            console.log("\tdeadline reached.");
        }

        // End auction
        console.log("\tending auction...");
        await market.connect(buyer1).endAuction(auctionId);
        console.log("\tauction ended.");

        // Final data
        const endItem = await market.fetchItem(itemId);
        const endSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const endArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const royaltiesAmount = (bid4Amount * royaltyValue) / 10000;
        const marketFeeAmount = ((bid4Amount - royaltiesAmount) * marketFee) / 10000;
        await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endBuyer2TokenAmount = await nft.balanceOf(buyer2Address, tokenId);
        const endNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Evaluate results
        expect(endItem.sales[0].seller).to.equal(sellerAddress);
        expect(endItem.sales[0].buyer).to.equal(buyer2Address);
        expect(formatBigNumber(endItem.sales[0].price)).to.equal(formatBigNumber(bid4Amount));
        expect(endBuyer2TokenAmount - iniBuyer2TokenAmount).to.equal(tokensAmount);
        expect(iniNumAuctions - endNumAuctions).to.equal(1);
        expect(endArtistBalance).to.equal(iniArtistBalance + formatBigNumber(royaltiesAmount));
        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(
            formatBigNumber(iniOwnerMarketBalance) + formatBigNumber(marketFeeAmount)
        );
        expect(endSellerBalance).to.equal(
            iniSellerBalance +
                formatBigNumber(bid4Amount) -
                formatBigNumber(royaltiesAmount) -
                formatBigNumber(marketFeeAmount)
        );
        expect(endMarketBalance).to.equal(
            iniMarketBalance -
                formatBigNumber(bid4Amount) +
                formatBigNumber(endOwnerMarketBalance) -
                formatBigNumber(iniOwnerMarketBalance)
        );
    });

    it.skip("Should end auction without bids", async () => {
        // Initial data
        const iniBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer1");
        const iniBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const iniNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Approve market contract for this address
        console.log("\tcreating approval for market contract...");
        await nft.connect(buyer2).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Create auction
        const tx = await market.connect(buyer2).createItemAuction(itemId, tokensAmount, 1, minBid);
        const receipt = await tx.wait();
        auctionId = receipt.events[1].args[0];
        console.log("\tauction created.");
        await getBalance(balanceHelper, buyer2Address, "buyer2");

        // Try to end auction
        console.log("\tending auction...");
        await throwsException(
            market.connect(buyer2).endAuction(auctionId),
            "SqwidMarket: Deadline not reached"
        );

        // Wait until deadline
        const auctionData = (await market.fetchPositionsByState(2)).at(-1).auctionData;
        deadline = new Date(auctionData.deadline * 1000);
        const timeUntilDeadline = deadline - new Date();
        console.log(`\ttime until deadline: ${timeUntilDeadline / 1000} secs.`);
        if (timeUntilDeadline > 0) {
            console.log("\twaiting for deadline...");
            await delay(timeUntilDeadline + 15000);
            console.log("\tdeadline reached.");
        }

        // End auction
        console.log("\tending auction...");
        await market.connect(buyer2).endAuction(auctionId);
        console.log("\tauction ended.");

        // Final data
        const endBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const endBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const endNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Evaluate results
        expect(endBuyer2Balance)
            .to.lte(iniBuyer2Balance)
            .to.gt(iniBuyer2Balance - formatBigNumber(maxGasFee));
        expect(endBuyer2TokenAmount).to.equal(iniBuyer2TokenAmount);
        expect(endNumAuctions).to.equal(iniNumAuctions);
    });
});
