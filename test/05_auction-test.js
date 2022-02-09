const { expect } = require("chai");
const {
    getMainContracts,
    getBalanceHelper,
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
        bid4Amount,
        bid5Amount;

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
        bid1Amount = ethers.utils.parseUnits("49", "ether"); // bid user 1
        bid2Amount = ethers.utils.parseUnits("60", "ether"); // bid user 1
        bid3Amount = ethers.utils.parseUnits("62", "ether"); // bid user 2
        bid4Amount = ethers.utils.parseUnits("1", "ether"); // bid user 2
        bid5Amount = ethers.utils.parseUnits("4", "ether"); // bid user 1
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
            .mint(tokensAmount, "https://fake-uri.com", "image", artistAddress, royaltyValue);
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
        expect(Number(auction.auctionData.minBid)).equals(Number(minBid));
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
        expect(Number(auctionData.highestBid)).equals(Number(bid2Amount));
        expect(auctionData.highestBidder).equals(buyer1Address);
        expect(Number(endBuyer1Balance))
            .to.lte(Number(iniBuyer1Balance.sub(bid2Amount)))
            .gt(Number(iniBuyer1Balance.sub(bid2Amount).sub(maxGasFee)));
        expect(Number(endMarketBalance)).to.equal(Number(iniMarketBalance.add(bid2Amount)));
    });

    it("Should not allow bids equal or lower than highest bid", async () => {
        console.log("\tbuyer2 creating bid...");
        await throwsException(
            market.connect(buyer2).createBid(auctionId, { value: bid2Amount }),
            "SqwidMarket: Bid value invalid"
        );
    });

    it("Should outbid", async () => {
        // Initial data
        const iniBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        // Creates bid
        console.log("\tbuyer2 creating bid...");
        await market.connect(buyer2).createBid(auctionId, { value: bid3Amount });
        console.log("\tbid created");

        // Final data
        const endBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);

        // Evaluate results
        expect(deadline.getTime()).equals(oldDeadline.getTime());
        expect(Number(auctionData.highestBid)).equals(Number(bid3Amount));
        expect(auctionData.highestBidder).equals(buyer2Address);
        expect(Number(endBuyer2Balance))
            .to.lte(Number(iniBuyer2Balance.sub(bid3Amount)))
            .gt(Number(iniBuyer2Balance.sub(bid3Amount).sub(maxGasFee)));
        expect(Number(endMarketBalance)).to.equal(Number(iniMarketBalance.add(bid3Amount)));
    });

    it("Should increase bid for highest bidder", async () => {
        // Creates bid
        console.log("\tbuyer2 creating bid...");
        await market.connect(buyer2).createBid(auctionId, { value: bid4Amount });
        console.log("\tbid created");

        // Final data
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);

        // Evaluate results
        expect(deadline.getTime()).equals(oldDeadline.getTime());
        expect(Number(auctionData.highestBid)).equals(Number(bid3Amount.add(bid4Amount)));
        expect(auctionData.highestBidder).equals(buyer2Address);
    });

    it("Should increase for non-highest bidder and extend auction deadline", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
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
        console.log("\tbuyer1 creating bid...");
        await market.connect(buyer1).createBid(auctionId, { value: bid5Amount });
        console.log("\tbid created");

        // Final data
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);
        console.log(`\tdeadline extended by ${(deadline - oldDeadline) / 1000} secs.`);

        // Evaluate results
        expect(deadline.getTime()).gt(oldDeadline.getTime());
        expect(Number(auctionData.highestBid)).equals(Number(bid2Amount.add(bid5Amount)));
        expect(auctionData.highestBidder).equals(buyer1Address);
        expect(Number(endBuyer1Balance))
            .to.lte(Number(iniBuyer1Balance.sub(bid5Amount)))
            .gt(Number(iniBuyer1Balance.sub(bid5Amount).sub(maxGasFee)));
        expect(Number(endMarketBalance)).to.equal(Number(iniMarketBalance.add(bid5Amount)));
    });

    it.skip("Should end auction with bids", async () => {
        // Initial data
        const iniSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const iniArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniBuyer2MarketBalance = await market.addressBalance(buyer2Address);
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");
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
        const iniBuyer1TokenAmount = await nft.balanceOf(buyer1Address, tokenId);

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
        await market.connect(buyer2).endAuction(auctionId);
        console.log("\tauction ended.");

        // Final data
        const endItem = await market.fetchItem(itemId);
        const endSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const endArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endBuyer2MarketBalance = await market.addressBalance(buyer2Address);
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const royaltiesAmountRaw = (bid2Amount.add(bid5Amount) * royaltyValue) / 10000;
        const royaltiesAmount = ethers.utils.parseUnits(royaltiesAmountRaw.toString(), "wei");
        const marketFeeAmountRaw =
            (bid2Amount.add(bid5Amount).sub(royaltiesAmount) * marketFee) / 10000;
        const marketFeeAmount = ethers.utils.parseUnits(marketFeeAmountRaw.toString(), "wei");
        const endBuyer1TokenAmount = await nft.balanceOf(buyer1Address, tokenId);
        const endNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Evaluate results
        expect(endItem.sales[0].seller).to.equal(sellerAddress);
        expect(endItem.sales[0].buyer).to.equal(buyer1Address);
        expect(Number(endItem.sales[0].price)).to.equal(Number(bid2Amount.add(bid5Amount)));
        expect(endBuyer1TokenAmount - iniBuyer1TokenAmount).to.equal(tokensAmount);
        expect(iniNumAuctions - endNumAuctions).to.equal(1);
        expect(Number(endArtistBalance)).to.equal(Number(iniArtistBalance.add(royaltiesAmount)));
        expect(Number(endOwnerMarketBalance)).to.equal(
            Number(iniOwnerMarketBalance.add(marketFeeAmount))
        );
        expect(Number(endSellerBalance)).to.equal(
            Number(
                iniSellerBalance
                    .add(bid2Amount)
                    .add(bid5Amount)
                    .sub(royaltiesAmount)
                    .sub(marketFeeAmount)
            )
        );
        expect(Number(endMarketBalance)).to.equal(
            Number(
                iniMarketBalance
                    .sub(bid2Amount)
                    .sub(bid5Amount)
                    .add(endOwnerMarketBalance)
                    .sub(iniOwnerMarketBalance)
            )
        );
        expect(Number(endBuyer2MarketBalance.sub(iniBuyer2MarketBalance))).to.equal(
            Number(bid3Amount.add(bid4Amount))
        );
    });

    it.skip("Should withdraw bidded amount", async () => {
        const iniBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const iniBuyer2MarketBalance = await market.addressBalance(buyer2Address);
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        console.log("\tuser 2 withdrawing balance...");
        await market.connect(buyer2).withdraw();
        console.log("\tWithdrawing completed.");
        const endBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const endBuyer2MarketBalance = await market.addressBalance(buyer2Address);
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");

        expect(Number(iniBuyer2MarketBalance)).to.equal(
            Number(iniMarketBalance.sub(endMarketBalance))
        );
        expect(Number(iniBuyer2MarketBalance))
            .to.gte(Number(endBuyer2Balance.sub(iniBuyer2Balance)))
            .to.lt(Number(endBuyer2Balance.sub(iniBuyer2Balance).add(maxGasFee)));
        expect(Number(endBuyer2MarketBalance)).to.equal(0);
    });

    it.skip("Should end auction without bids", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const iniBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const iniNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Approve market contract for this address
        console.log("\tcreating approval for market contract...");
        await nft.connect(buyer1).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Create auction
        const tx = await market.connect(buyer1).createItemAuction(itemId, tokensAmount, 1, minBid);
        const receipt = await tx.wait();
        auctionId = receipt.events[1].args[0];
        console.log("\tauction created.");
        await getBalance(balanceHelper, buyer1Address, "buyer1");

        // Try to end auction
        console.log("\tending auction...");
        await throwsException(
            market.connect(buyer1).endAuction(auctionId),
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
        await market.connect(buyer1).endAuction(auctionId);
        console.log("\tauction ended.");

        // Final data
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const endNumAuctions = (await market.fetchPositionsByState(2)).length;

        // Evaluate results
        expect(Number(endBuyer1Balance))
            .to.lte(Number(iniBuyer1Balance))
            .to.gt(Number(iniBuyer1Balance.sub(maxGasFee)));
        expect(endBuyer1TokenAmount).to.equal(iniBuyer1TokenAmount);
        expect(endNumAuctions).to.equal(iniNumAuctions);
    });
});
