const { expect, assert } = require("chai");
const ReefAbi = require("./ReefToken.json");

describe("************ Raffles ******************", () => {
    let market,
        nft,
        owner,
        seller,
        artist,
        buyer1,
        buyer2,
        helper,
        marketFee,
        marketContractAddress,
        nftContractAddress,
        ownerAddress,
        sellerAddress,
        artistAddress,
        buyer1Address,
        buyer2Address,
        helperAddress,
        reefToken,
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
        // Deployed contract addresses (comment to deploy new contracts)
        marketContractAddress = config.contracts.market;
        nftContractAddress = config.contracts.nft;

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

        // Initialize and connect to Reef token
        const ReefToken = new ethers.Contract(config.contracts.reef, ReefAbi, owner);
        reefToken = ReefToken.connect(owner);

        // Initialize global variables
        marketFee = 250; // 2.5%
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        numMinutes = 1;
        buyer1RaffleAmount = ethers.utils.parseUnits("100", "ether");
        buyer2RaffleAmount = ethers.utils.parseUnits("50", "ether");
        royaltyValue = 1000; // 10%
        tokensAmount = 15;

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
            nft = await NFT.deploy(marketContractAddress);
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

    it("Should create raffle", async () => {
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
        const iniRaffles = await market.fetchAllRaffles();
        const iniSellerTokenAmount = await nft.balanceOf(sellerAddress, tokenId);
        const iniMarketTokenAmount = await nft.balanceOf(marketContractAddress, tokenId);

        // Create raffle
        console.log("\tseller creating raffle...");
        await getBalance(sellerAddress, "seller");
        await market
            .connect(seller)
            .createNewNftRaffle(nftContractAddress, tokenId, tokensAmount, numMinutes);
        console.log("\traffle created.");
        await getBalance(sellerAddress, "seller");

        // Final data
        const endRaffles = await market.fetchAllRaffles();
        const raffle = endRaffles.at(-1);
        raffleId = raffle.positionId;
        const itemUri = await nft.uri(raffle.item.tokenId);
        itemId = Number(raffle.item.itemId);
        const endSellerTokenAmount = await nft.balanceOf(sellerAddress, tokenId);
        const endMarketTokenAmount = await nft.balanceOf(marketContractAddress, tokenId);
        deadline = new Date(raffle.raffleData.deadline * 1000);

        // Evaluate results
        expect(iniSellerTokenAmount - endSellerTokenAmount).to.equal(tokensAmount);
        expect(endMarketTokenAmount - iniMarketTokenAmount).to.equal(tokensAmount);
        expect(endRaffles.length).to.equal(iniRaffles.length + 1);
        expect(itemUri).to.equal("https://fake-uri.com");
        expect(raffle.item.nftContract).to.equal(nftContractAddress);
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
        const iniBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const iniBuyer2Balance = await getBalance(buyer2Address, "buyer2");
        const iniMarketBalance = await getBalance(marketContractAddress, "market");

        // Add entries
        console.log("\tbuyer1 enters NFT raffle...");
        await market.connect(buyer1).enterRaffle(raffleId, { value: buyer1RaffleAmount });
        console.log("\tbuyer1 entry created");
        console.log("\tbuyer2 enters NFT raffle...");
        await market.connect(buyer2).enterRaffle(raffleId, { value: buyer2RaffleAmount });
        console.log("\tbuyer2 entry created");

        // Final data
        const endBuyer1Balance = await getBalance(buyer1Address, "buyer1");
        const endBuyer2Balance = await getBalance(buyer2Address, "buyer2");
        const endMarketBalance = await getBalance(marketContractAddress, "market");
        const raffle = await market.fetchPosition(raffleId);

        // Evaluate results
        expect(Math.round(endBuyer1Balance))
            .to.lte(Math.round(iniBuyer1Balance - formatBigNumber(buyer1RaffleAmount)))
            .gt(
                Math.round(
                    iniBuyer1Balance -
                        formatBigNumber(buyer1RaffleAmount) -
                        formatBigNumber(maxGasFee)
                )
            );
        expect(Math.round(endBuyer2Balance))
            .to.lte(Math.round(iniBuyer2Balance - formatBigNumber(buyer2RaffleAmount)))
            .gt(
                Math.round(
                    iniBuyer2Balance -
                        formatBigNumber(buyer2RaffleAmount) -
                        formatBigNumber(maxGasFee)
                )
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
            "SqwidMarketplace: Raffle deadline has not been reached yet."
        );
    });

    it("Should end raffle and send NFT to winner", async () => {
        // Initial data
        const iniRaffles = await market.fetchAllRaffles();
        const iniSellerBalance = await getBalance(sellerAddress, "seller");
        const iniArtistBalance = await getBalance(artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(marketContractAddress, "market");
        await getBalance(helperAddress, "helper");
        const iniBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const iniBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const iniMarketTokenAmount = Number(await nft.balanceOf(marketContractAddress, tokenId));

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
        const endRaffles = await market.fetchAllRaffles();
        const endItem = await market.fetchItem(itemId);
        const endSellerBalance = await getBalance(sellerAddress, "seller");
        const endArtistBalance = await getBalance(artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(marketContractAddress, "market");
        const royaltiesAmount = (buyer1RaffleAmount.add(buyer2RaffleAmount) * royaltyValue) / 10000;
        const marketFeeAmount =
            ((buyer1RaffleAmount.add(buyer2RaffleAmount) - royaltiesAmount) * marketFee) / 10000;
        await getBalance(helperAddress, "helper");
        const endBuyer1TokenAmount = Number(await nft.balanceOf(buyer1Address, tokenId));
        const endBuyer2TokenAmount = Number(await nft.balanceOf(buyer2Address, tokenId));
        const endMarketTokenAmount = Number(await nft.balanceOf(marketContractAddress, tokenId));

        // Evaluate results
        expect(iniMarketTokenAmount - endMarketTokenAmount).to.equal(tokensAmount);
        expect(
            endBuyer1TokenAmount +
                endBuyer2TokenAmount -
                iniBuyer1TokenAmount -
                iniBuyer2TokenAmount
        ).to.equal(tokensAmount);
        expect(Math.round(endArtistBalance)).to.equal(
            Math.round(iniArtistBalance + formatBigNumber(royaltiesAmount))
        );
        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(
            formatBigNumber(iniOwnerMarketBalance) + formatBigNumber(marketFeeAmount)
        );
        expect(Math.round(endSellerBalance)).to.equal(
            Math.round(
                iniSellerBalance +
                    formatBigNumber(buyer1RaffleAmount) +
                    formatBigNumber(buyer2RaffleAmount) -
                    formatBigNumber(royaltiesAmount) -
                    formatBigNumber(marketFeeAmount)
            )
        );
        console.log(endMarketBalance);
        console.log(iniMarketBalance);
        console.log(formatBigNumber(buyer1RaffleAmount));
        console.log(formatBigNumber(buyer2RaffleAmount));
        console.log(formatBigNumber(marketFeeAmount));
        expect(endMarketBalance).to.equal(
            iniMarketBalance -
                formatBigNumber(buyer1RaffleAmount) -
                formatBigNumber(buyer2RaffleAmount) +
                formatBigNumber(marketFeeAmount)
        );

        expect(endItem.sales[0].seller).to.equal(sellerAddress);
        expect(endItem.sales[0].buyer).to.be.oneOf([buyer1Address, buyer2Address]);
        expect(Number(endItem.sales[0].price)).to.equal(
            Number(buyer1RaffleAmount.add(buyer2RaffleAmount))
        );
        expect(iniRaffles.length - endRaffles.length).to.equal(1);
    });

    it("Create new raffle with existing market item", async () => {
        // Initial data
        const iniRaffles = await market.fetchAllRaffles();
        const iniBuyer1TokenAmount = await nft.balanceOf(buyer1Address, tokenId);
        const signer = Number(iniBuyer1TokenAmount) > 0 ? buyer1 : buyer2;

        // Approve market contract for this address
        console.log("\tcreating approval for market contract...");
        await nft.connect(signer).setApprovalForAll(marketContractAddress, true);
        console.log("\tApproval created");

        // Create raffle
        console.log("\tcreating NFT raffle...");
        await market.connect(signer).createItemRaffle(itemId, tokensAmount, numMinutes);
        console.log("\tNFT raffle created");

        // Final data
        const endRaffles = await market.fetchAllRaffles();

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
        const iniRaffles = await market.fetchAllRaffles();
        const iniSellerTokenAmount = Number(await nft.balanceOf(sellerAddress, tokenId));
        const iniSellerPositions = await market.connect(seller).fetchMyPositions();
        const iniTokenPositions = iniSellerPositions.filter((pos) => pos.item.tokenId == tokenId);

        // Create raffle
        console.log("\tseller creating raffle...");
        await getBalance(sellerAddress, "seller");
        const tx2 = await market
            .connect(seller)
            .createNewNftRaffle(nftContractAddress, tokenId, tokensAmount, numMinutes);
        const receipt2 = await tx2.wait();
        raffleId = receipt2.events[3].args[0];
        console.log(`\traffle created with id ${raffleId}`);
        await getBalance(sellerAddress, "seller");
        const midSellerPositions = await market.connect(seller).fetchMyPositions();
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
        const endRaffles = await market.fetchAllRaffles();
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
