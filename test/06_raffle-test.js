const { expect } = require("chai");
const {
    getMainContracts,
    getBalanceHelper,
    formatBigNumber,
    getBalance,
    throwsException,
    delay,
} = require("./util");

describe("************ Raffles ******************", () => {
    let market,
        nft,
        balanceHelper,
        owner,
        seller,
        artist,
        buyer1,
        buyer2,
        helper,
        marketFee,
        ownerAddress,
        sellerAddress,
        artistAddress,
        buyer1Address,
        buyer2Address,
        helperAddress,
        tokenId,
        itemId,
        raffleId,
        royaltyValue,
        maxGasFee,
        numMinutes,
        buyer1RaffleAmount,
        buyer2RaffleAmount,
        tokensAmount;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        seller = await reef.getSignerByName("account2");
        buyer1 = await reef.getSignerByName("account3");
        buyer2 = await reef.getSignerByName("account4");
        artist = await reef.getSignerByName("account5");
        helper = await reef.getSignerByName("account6");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        sellerAddress = await seller.getAddress();
        buyer1Address = await buyer1.getAddress();
        buyer2Address = await buyer2.getAddress();
        artistAddress = await artist.getAddress();
        helperAddress = await helper.getAddress();

        // Initialize global variables
        marketFee = 250; // 2.5%
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        numMinutes = 1;
        buyer1RaffleAmount = ethers.utils.parseUnits("100", "ether");
        buyer2RaffleAmount = ethers.utils.parseUnits("50", "ether");
        royaltyValue = 1000; // 10%
        tokensAmount = 15;

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        balanceHelper = await getBalanceHelper();
    });

    it("Should create raffle", async () => {
        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(seller).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Initial data
        const iniRaffles = await market.fetchPositionsByState(3);

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(seller)
            .mint(tokensAmount, "https://fake-uri.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        itemId = receipt1.events[2].args[0].toNumber();
        tokenId = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Create raffle
        console.log("\tseller creating raffle...");
        await market.connect(seller).createItemRaffle(itemId, tokensAmount, numMinutes);
        console.log("\traffle created.");

        // Final data
        const endRaffles = await market.fetchPositionsByState(3);
        const raffle = endRaffles.at(-1);
        raffleId = raffle.positionId;
        const itemUri = await nft.uri(raffle.item.tokenId);
        itemId = Number(raffle.item.itemId);
        const endSellerTokenAmount = await nft.balanceOf(sellerAddress, tokenId);
        const endMarketTokenAmount = await nft.balanceOf(market.address, tokenId);
        deadline = new Date(raffle.raffleData.deadline * 1000);

        // Evaluate results
        expect(Number(endSellerTokenAmount)).to.equal(0);
        expect(Number(endMarketTokenAmount)).to.equal(tokensAmount);
        expect(endRaffles.length).to.equal(iniRaffles.length + 1);
        expect(itemUri).to.equal("https://fake-uri.com");
        expect(raffle.item.nftContract).to.equal(nft.address);
        expect(Number(raffle.item.tokenId)).to.equal(tokenId);
        expect(raffle.owner).to.equal(sellerAddress);
        expect(raffle.item.creator).to.equal(sellerAddress);
        expect(Number(raffle.marketFee)).to.equal(Number(marketFee));
        expect(raffle.state).to.equal(3); // Raffle = 3
        expect(deadline)
            .to.lt(new Date(new Date().getTime() + 120000))
            .gt(new Date());
    });

    it("Should add entries to the raffle", async () => {
        // Initial data
        const iniBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const iniBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");

        // Add entries
        console.log("\tbuyer1 enters NFT raffle...");
        await market.connect(buyer1).enterRaffle(raffleId, { value: buyer1RaffleAmount });
        console.log("\tbuyer1 entry created");
        console.log("\tbuyer2 enters NFT raffle...");
        await market.connect(buyer2).enterRaffle(raffleId, { value: buyer2RaffleAmount });
        console.log("\tbuyer2 entry created");

        // Final data
        const endBuyer1Balance = await getBalance(balanceHelper, buyer1Address, "buyer1");
        const endBuyer2Balance = await getBalance(balanceHelper, buyer2Address, "buyer2");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const raffle = await market.fetchPosition(raffleId);

        // Evaluate results
        expect(endBuyer1Balance)
            .to.lte(iniBuyer1Balance - formatBigNumber(buyer1RaffleAmount))
            .gt(
                iniBuyer1Balance - formatBigNumber(buyer1RaffleAmount) - formatBigNumber(maxGasFee)
            );
        expect(endBuyer2Balance)
            .to.lte(iniBuyer2Balance - formatBigNumber(buyer2RaffleAmount))
            .gt(
                iniBuyer2Balance - formatBigNumber(buyer2RaffleAmount) - formatBigNumber(maxGasFee)
            );
        expect(endMarketBalance)
            .to.gte(
                iniMarketBalance +
                    formatBigNumber(buyer1RaffleAmount) +
                    formatBigNumber(buyer2RaffleAmount)
            )
            .lt(
                iniMarketBalance +
                    formatBigNumber(buyer1RaffleAmount) +
                    formatBigNumber(buyer2RaffleAmount) +
                    1
            );
        expect(Number(raffle.raffleData.totalAddresses)).to.equal(2);

        expect(Number(raffle.raffleData.totalValue)).to.equal(
            formatBigNumber(buyer1RaffleAmount) + formatBigNumber(buyer2RaffleAmount)
        );
    });

    it("Should not end raffle before deadline", async () => {
        console.log("\tending raffle...");
        await throwsException(
            market.connect(seller).endRaffle(raffleId),
            "SqwidMarket: Deadline not reached"
        );
    });

    it("Should end raffle and send NFT to winner", async () => {
        // Initial data
        const iniRaffles = await market.fetchPositionsByState(3);
        const iniSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const iniArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");
        await getBalance(balanceHelper, helperAddress, "helper");
        const iniBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const iniBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const iniMarketTokenAmount = Number(await nft.balanceOf(market.address, tokenId));

        // Wait until deadline
        const timeUntilDeadline = deadline - new Date();
        console.log(`\ttime until deadline: ${timeUntilDeadline / 1000} secs.`);
        if (timeUntilDeadline > 0) {
            console.log("\twaiting for deadline...");
            await delay(timeUntilDeadline + 15000);
            console.log("\tdeadline reached.");
        }

        // End raffle
        console.log("\tending raffle...");
        await market.connect(helper).endRaffle(raffleId);
        console.log("\traffle ended.");

        // Final data
        const endRaffles = await market.fetchPositionsByState(3);
        const endItem = await market.fetchItem(itemId);
        const endSellerBalance = await getBalance(balanceHelper, sellerAddress, "seller");
        const endArtistBalance = await getBalance(balanceHelper, artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const royaltiesAmount = (buyer1RaffleAmount.add(buyer2RaffleAmount) * royaltyValue) / 10000;
        const marketFeeAmount =
            ((buyer1RaffleAmount.add(buyer2RaffleAmount) - royaltiesAmount) * marketFee) / 10000;
        await getBalance(balanceHelper, helperAddress, "helper");
        const endBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const endBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const endMarketTokenAmount = Number(await nft.balanceOf(market.address, tokenId));

        // Evaluate results
        expect(iniMarketTokenAmount - endMarketTokenAmount).to.equal(tokensAmount);
        expect(
            endBuyer1TokenAmount +
                endBuyer2TokenAmount -
                iniBuyer1TokenAmount -
                iniBuyer2TokenAmount
        ).to.equal(tokensAmount);
        expect(endArtistBalance).to.equal(iniArtistBalance + formatBigNumber(royaltiesAmount));
        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(
            formatBigNumber(iniOwnerMarketBalance) + formatBigNumber(marketFeeAmount)
        );
        expect(endSellerBalance * 1e18).to.equal(
            iniSellerBalance * 1e18 +
                Number(buyer1RaffleAmount) +
                Number(buyer2RaffleAmount) -
                Number(royaltiesAmount) -
                Number(marketFeeAmount)
        );
        expect(endMarketBalance * 1e18).to.equal(
            iniMarketBalance * 1e18 -
                Number(buyer1RaffleAmount) -
                Number(buyer2RaffleAmount) +
                Number(marketFeeAmount)
        );
        expect(endItem.sales[0].seller).to.equal(sellerAddress);
        expect(endItem.sales[0].buyer).to.be.oneOf([buyer1Address, buyer2Address]);
        expect(formatBigNumber(endItem.sales[0].price)).to.equal(
            formatBigNumber(buyer1RaffleAmount.add(buyer2RaffleAmount))
        );
        expect(iniRaffles.length - endRaffles.length).to.equal(1);
    });

    it("Create new raffle with existing market item", async () => {
        // Initial data
        const iniRaffles = await market.fetchPositionsByState(3);
        const iniBuyer1TokenAmount = await nft.balanceOf(buyer1Address, tokenId);
        const signer = Number(iniBuyer1TokenAmount) > 0 ? buyer1 : buyer2;

        // Approve market contract for this address
        console.log("\tcreating approval for market contract...");
        await nft.connect(signer).setApprovalForAll(market.address, true);
        console.log("\tApproval created");

        // Create raffle
        console.log("\tcreating NFT raffle...");
        await market.connect(signer).createItemRaffle(itemId, tokensAmount, numMinutes);
        console.log("\tNFT raffle created");

        // Final data
        const endRaffles = await market.fetchPositionsByState(3);

        // Evaluate result
        expect(endRaffles.length - iniRaffles.length).to.equal(1);
    });

    it("Should create raffle and end it without participants", async () => {
        // Create NFT
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
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Initial data
        const iniRaffles = await market.fetchPositionsByState(3);
        const iniSellerTokenAmount = Number(await nft.balanceOf(sellerAddress, tokenId));
        const iniSellerPositions = await market.fetchAddressPositions(sellerAddress);
        const iniTokenPositions = iniSellerPositions.filter((pos) => pos.item.tokenId == tokenId);

        // Create market item
        const tx2 = await market.connect(seller).createItem(nft.address, tokenId);
        const receipt2 = await tx2.wait();
        itemId = receipt2.events[1].args[0].toNumber();

        // Create raffle
        console.log("\tseller creating raffle...");
        await getBalance(balanceHelper, sellerAddress, "seller");
        const tx3 = await market.connect(seller).createItemRaffle(itemId, tokensAmount, numMinutes);
        const receipt3 = await tx3.wait();
        raffleId = receipt3.events[1].args[0];
        console.log(`\traffle created with id ${raffleId}`);
        await getBalance(balanceHelper, sellerAddress, "seller");
        const midSellerPositions = await market.fetchAddressPositions(sellerAddress);
        const midTokenPositions = midSellerPositions.filter((pos) => pos.item.tokenId == tokenId);

        // Wait until deadline reached
        console.log("\twaiting for deadline...");
        await delay(75000);
        console.log("\tDeadline reached");

        // End raffle
        console.log("\tending raffle...");
        await market.connect(helper).endRaffle(raffleId);
        console.log("\traffle ended.");

        // Final data
        const endRaffles = await market.fetchPositionsByState(3);
        const endSellerTokenAmount = Number(await nft.balanceOf(sellerAddress, tokenId));
        const endSellerPositions = await market.fetchAddressPositions(sellerAddress);
        const endTokenPositions = endSellerPositions.filter((pos) => pos.item.tokenId == tokenId);

        // Evaluate results
        expect(endSellerTokenAmount).to.equal(iniSellerTokenAmount);
        expect(endSellerTokenAmount).to.equal(tokensAmount);
        expect(endRaffles.length).to.equal(iniRaffles.length);
        expect(iniTokenPositions.length).to.equal(0);
        expect(midTokenPositions.length).to.equal(2);
        expect(midTokenPositions[0].state).to.equal(0); // Available = 0
        expect(midTokenPositions[1].state).to.equal(3); // Raffle = 3
        expect(endTokenPositions.length).to.equal(1);
        expect(endTokenPositions[0].state).to.equal(0); // Avalilable = 0
    });
});
