const { expect, assert } = require("chai");
const ReefAbi = require("./ReefToken.json");

describe.only("************ Auctions ******************", () => {
    let market,
        nft,
        owner,
        seller,
        artist,
        buyer1,
        buyer2,
        marketFee,
        marketContractAddress,
        nftContractAddress,
        ownerAddress,
        sellerAddress,
        artistAddress,
        buyer1Address,
        buyer2Address,
        reefToken,
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
        // Deployed contract addresses (comment to deploy new contracts)
        marketContractAddress = config.contracts.market;
        nftContractAddress = config.contracts.nft;

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

        // Initialize and connect to Reef token
        const ReefToken = new ethers.Contract(config.contracts.reef, ReefAbi, owner);
        reefToken = ReefToken.connect(owner);

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

        if (!marketContractAddress || marketContractAddress == "") {
            // Deploy SqwidMarketplace contract
            console.log("\tdeploying Market contract...");
            await getBalance(ownerAddress, "owner");
            const Market = await reef.getContractFactory("SqwidMarketplace", owner);
            market = await Market.deploy(marketFee);
            await market.deployed();
            marketContractAddress = market.address;
            await getBalance(ownerAddress, "owner");

            if (nftContractAddress) {
                const NFT = await reef.getContractFactory("SqwidERC1155", owner);
                nft = await NFT.attach(nftContractAddress);
                await nft.connect(owner).setMarketplaceAddress(marketContractAddress);
            }
        } else {
            // Get deployed contract
            const Market = await reef.getContractFactory("SqwidMarketplace", owner);
            market = await Market.attach(marketContractAddress);
        }
        console.log(`\tMarket contract deployed in ${marketContractAddress}`);

        if (!nftContractAddress || nftContractAddress == "") {
            // Deploy SqwidERC1155 contract
            console.log("\tdeploying NFT contract...");
            await getBalance(ownerAddress, "owner");
            const NFT = await reef.getContractFactory("SqwidERC1155", owner);
            const loanContractAddress = config.contracts.loan
                ? config.contracts.loan
                : "0x0000000000000000000000000000000000000000";
            nft = await NFT.deploy(marketContractAddress, loanContractAddress);
            await nft.deployed();
            nftContractAddress = nft.address;
            await getBalance(ownerAddress, "owner");
        } else {
            // Get deployed contract
            const NFT = await reef.getContractFactory("SqwidERC1155", owner);
            nft = await NFT.attach(nftContractAddress);
        }
        console.log(`\tNFT contact deployed ${nftContractAddress}`);
    });

    it("Should create auction", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(seller)
            .mint(
                sellerAddress,
                tokensAmount,
                "https://fake-uri.com",
                artistAddress,
                royaltyValue,
                true
            );
        const receipt1 = await tx1.wait();
        tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFTs created with tokenId ${tokenId}`);

        // Initial data
        const iniAuctions = await market.fetchAllAuctions();
        const iniSellerTokenAmount = await nft.balanceOf(sellerAddress, tokenId);

        // Create auction
        console.log("\tseller creating auction...");
        await getBalance(sellerAddress, "seller");
        await market
            .connect(seller)
            .createNewItemAuction(nftContractAddress, tokenId, tokensAmount, numMinutes, minBid);
        console.log("\tauction created.");
        await getBalance(sellerAddress, "seller");

        // Final data
        const endAuctions = await market.fetchAllAuctions();
        const auction = endAuctions.at(-1);
        auctionId = auction.positionId;
        const tokenUri = await nft.uri(tokenId);
        const endSellerTokenAmount = await nft.balanceOf(sellerAddress, tokenId);
        deadline = new Date(auction.auctionData.deadline * 1000);

        // Evaluate results
        expect(iniSellerTokenAmount - endSellerTokenAmount).to.equal(tokensAmount);
        expect(endAuctions.length).to.equal(iniAuctions.length + 1);
        expect(tokenUri).to.equal("https://fake-uri.com");
        expect(auction.item.nftContract).to.equal(nftContractAddress);
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
            "SqwidMarketplace: Bid value cannot be lower than minimum bid."
        );
    });

    it("Should create bid", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const iniMarketBalance = await getBalance(marketContractAddress, "market");

        // Creates bid
        console.log("\tbuyer1 creating bid...");
        await market.connect(buyer1).createBid(auctionId, { value: bid2Amount });
        console.log("\tbid created");

        // Final data
        const endBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const endMarketBalance = await getBalance(marketContractAddress, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);

        // Evaluate results
        expect(deadline.getTime()).equals(oldDeadline.getTime());
        expect(Number(auctionData.highestBid)).equals(Number(bid2Amount));
        expect(auctionData.highestBidder).equals(buyer1Address);
        expect(Math.round(endBuyer1Balance))
            .to.lte(Math.round(iniBuyer1Balance - formatBigNumber(bid2Amount)))
            .gt(
                Math.round(
                    iniBuyer1Balance - formatBigNumber(bid2Amount) - formatBigNumber(maxGasFee)
                )
            );
        expect(endMarketBalance)
            .to.gte(iniMarketBalance + formatBigNumber(bid2Amount))
            .lt(iniMarketBalance + formatBigNumber(bid2Amount) + 1);
    });

    it("Should not allow bids equal or lower than highest bid", async () => {
        console.log("\tbuyer2 creating bid...");
        await throwsException(
            market.connect(buyer2).createBid(auctionId, { value: bid2Amount }),
            "SqwidMarketplace: Bid value cannot be lower than highest bid."
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
        expect(Number(auctionData.highestBid)).equals(Number(bid2Amount.add(bid3Amount)));
        expect(auctionData.highestBidder).equals(buyer1Address);
    });

    it("Should extend auction deadline", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const iniBuyer2Balance = await getBalance(buyer2Address, "buyer2");
        const iniMarketBalance = await getBalance(marketContractAddress, "market");

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
        const endBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const endBuyer2Balance = await getBalance(buyer2Address, "buyer2");
        const endMarketBalance = await getBalance(marketContractAddress, "market");
        const oldDeadline = deadline;
        const auctionData = (await market.fetchPosition(auctionId)).auctionData;
        deadline = new Date(auctionData.deadline * 1000);
        console.log(`\tdeadline extended by ${(deadline - oldDeadline) / 1000} secs.`);
        const bidIncrease =
            formatBigNumber(bid4Amount) - formatBigNumber(bid2Amount) - formatBigNumber(bid3Amount);

        // Evaluate results
        expect(deadline.getTime()).gt(oldDeadline.getTime());
        expect(Number(auctionData.highestBid)).equals(Number(bid4Amount));
        expect(auctionData.highestBidder).equals(buyer2Address);
        expect(Math.round(endBuyer1Balance)).to.equals(
            Math.round(iniBuyer1Balance + formatBigNumber(bid2Amount) + formatBigNumber(bid3Amount))
        );
        expect(Math.round(endBuyer2Balance))
            .to.lte(Math.round(iniBuyer2Balance - formatBigNumber(bid4Amount)))
            .gt(
                Math.round(
                    iniBuyer2Balance - formatBigNumber(bid4Amount) - formatBigNumber(maxGasFee)
                )
            );
        expect(endMarketBalance)
            .to.gte(iniMarketBalance + bidIncrease)
            .lt(iniMarketBalance + bidIncrease + 1);
    });

    it.only("Should end auction with bids", async () => {
        // Initial data
        const iniSellerBalance = await getBalance(sellerAddress, "seller");
        const iniArtistBalance = await getBalance(artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(marketContractAddress, "market");
        await getBalance(buyer1Address, "buyer1");
        const auctions = await market.fetchAllAuctions();
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
        const endSellerBalance = await getBalance(sellerAddress, "seller");
        const endArtistBalance = await getBalance(artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(marketContractAddress, "market");
        const royaltiesAmount = (bid4Amount * royaltyValue) / 10000;
        const marketFeeAmount = ((bid4Amount - royaltiesAmount) * marketFee) / 10000;
        await getBalance(buyer1Address, "buyer1");
        const endBuyer2TokenAmount = await nft.balanceOf(buyer2Address, tokenId);
        const endNumAuctions = (await market.fetchAllAuctions()).length;

        // Evaluate results
        expect(endItem.sales[0].seller).to.equal(sellerAddress);
        expect(endItem.sales[0].buyer).to.equal(buyer2Address);
        expect(Number(endItem.sales[0].price)).to.equal(Number(bid4Amount));
        expect(endBuyer2TokenAmount - iniBuyer2TokenAmount).to.equal(tokensAmount);
        expect(iniNumAuctions - endNumAuctions).to.equal(1);
        expect(Math.round(endArtistBalance)).to.equal(
            Math.round(iniArtistBalance + formatBigNumber(royaltiesAmount))
        );
        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(
            formatBigNumber(iniOwnerMarketBalance) + formatBigNumber(marketFeeAmount)
        );
        expect(Math.round(endSellerBalance)).to.equal(
            Math.round(
                iniSellerBalance +
                    formatBigNumber(bid4Amount) -
                    formatBigNumber(royaltiesAmount) -
                    formatBigNumber(marketFeeAmount)
            )
        );
        expect(endMarketBalance).to.equal(
            iniMarketBalance -
                formatBigNumber(bid4Amount) +
                formatBigNumber(endOwnerMarketBalance) -
                formatBigNumber(iniOwnerMarketBalance)
        ); // TODO Here there is also a discrepancy of about ~0.064
    });

    it.only("Should end auction without bids", async () => {
        // Initial data
        const iniBuyer2Balance = await getBalance(buyer2Address, "buyer1");
        const iniBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const iniNumAuctions = (await market.fetchAllAuctions()).length;

        // Approve market contract for this address
        console.log("\tcreating approval for market contract...");
        await nft.connect(buyer2).setApprovalForAll(marketContractAddress, true);
        console.log("\tapproval created");

        // Create auction
        const tx = await market.connect(buyer2).createItemAuction(itemId, tokensAmount, 1, minBid);
        const receipt = await tx.wait();
        auctionId = receipt.events[1].args[0];
        console.log("\tauction created.");
        await getBalance(buyer2Address, "buyer2");

        // Try to end auction
        console.log("\tending auction...");
        await throwsException(
            market.connect(buyer2).endAuction(auctionId),
            "SqwidMarketplace: Auction deadline has not been reached yet."
        );

        // Wait until deadline
        const auctionData = (await market.fetchAllAuctions()).at(-1).auctionData;
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
        const endBuyer2Balance = await getBalance(buyer2Address, "buyer2");
        const endBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const endNumAuctions = (await market.fetchAllAuctions()).length;

        // Evaluate results
        expect(endBuyer2Balance)
            .to.lte(iniBuyer2Balance)
            .to.gt(iniBuyer2Balance - Number(maxGasFee));
        expect(endBuyer2TokenAmount).to.equal(iniBuyer2TokenAmount);
        expect(endNumAuctions).to.equal(iniNumAuctions);
    });

    async function getBalance(address, name) {
        const balance = await reefToken.balanceOf(address);
        const balanceFormatted = formatBigNumber(balance);
        console.log(`\t\tBalance of ${name}:`, balanceFormatted);

        return balanceFormatted;
    }

    function formatBigNumber(bigNumber) {
        return Number(Number(ethers.utils.formatUnits(bigNumber.toString(), "ether")).toFixed(4));
    }

    async function throwsException(promise, message) {
        try {
            await promise;
            assert(false);
        } catch (error) {
            expect(error.message).contains(message);
        }
    }

    const delay = (ms) => new Promise((res) => setTimeout(res, ms));

    async function logEvents(promise) {
        const tx = await promise;
        const receipt = await tx.wait();

        let msg = "No events for this tx";
        if (receipt.events) {
            const eventsArgs = [];
            receipt.events.forEach((event) => {
                if (event.args) {
                    eventsArgs.push(event.args);
                }
            });
            msg = eventsArgs;
        }
        console.log(msg);
    }
});
