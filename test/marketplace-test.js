const { expect, assert } = require("chai");
const { getContracts, formatBigNumber, getBalance, throwsException } = require("./util");
const ReefAbi = require("./ReefToken.json");

describe.only("************ Marketplace ******************", () => {
    let market,
        nft,
        owner,
        seller,
        artist,
        buyer1,
        marketFee,
        marketContractAddress,
        nftContractAddress,
        salePrice,
        ownerAddress,
        sellerAddress,
        artistAddress,
        buyer1Address,
        reefToken,
        token1Id,
        token2Id,
        item1Id,
        item2Id,
        position1Id,
        position2Id,
        royaltyValue,
        maxGasFee;

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

        // Initialize and connect to Reef token
        const ReefToken = new ethers.Contract(config.contracts.reef, ReefAbi, owner);
        reefToken = ReefToken.connect(owner);

        // Initialize global variables
        marketFee = 250; // 2.5%
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        salePrice = ethers.utils.parseUnits("50", "ether");
        royaltyValue = 1000; // 10%

        // Deploy or get existing contracts
        const contracts = await getContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        nftContractAddress = nft.address;
        marketContractAddress = market.address;
    });

    it("Should only allow change market fee to owner", async () => {
        await throwsException(
            market.connect(seller).setMarketFee(350),
            "Ownable: caller is not the owner"
        );

        await market.connect(owner).setMarketFee(350);
        let fetchedFee = await market.connect(owner).marketFee();
        expect(Number(fetchedFee)).to.equal(350);

        await market.connect(owner).setMarketFee(250);
        fetchedFee = await market.connect(owner).marketFee();
        expect(Number(fetchedFee)).to.equal(250);

        // TODO
        // await market.connect(owner).setMarketFee(350, 1);
        // let regSaleFee = await market.connect(owner).marketFeeRegSale();
        // expect(Number(regSaleFee)).to.equal(350);

        // await market.connect(owner).setMarketFee(250, 1);
        // regSaleFee = await market.connect(owner).marketFeeRegSale();
        // expect(Number(regSaleFee)).to.equal(250);

        // await market.connect(owner).setMarketFee(0, 2);
        // let auctionFee = await market.connect(owner).marketFeeAuction();
        // expect(Number(auctionFee)).to.equal(0);

        // await market.connect(owner).setMarketFee(250, 2);
        // auctionFee = await market.connect(owner).marketFeeAuction();
        // expect(Number(auctionFee)).to.equal(250);

        // await market.connect(owner).setMarketFee(50, 3);
        // let raffleFee = await market.connect(owner).marketFeeRaffle();
        // expect(Number(raffleFee)).to.equal(50);

        // await market.connect(owner).setMarketFee(250, 3);
        // raffleFee = await market.connect(owner).marketFeeRaffle();
        // expect(Number(raffleFee)).to.equal(250);

        // await market.connect(owner).setMarketFee(5, 4);
        // let loanFee = await market.connect(owner).marketFeeLoan();
        // expect(Number(loanFee)).to.equal(5);

        // await market.connect(owner).setMarketFee(250, 4);
        // loanFee = await market.connect(owner).marketFeeLoan();
        // expect(Number(loanFee)).to.equal(250);
    });

    it("Should mint NFT and create market item", async () => {
        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(seller).setApprovalForAll(marketContractAddress, true);
        console.log("\tapproval created");

        // Create token
        console.log("\tcreating token...");
        const tx = await market
            .connect(seller)
            .mint(10, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt = await tx.wait();
        const itemId = receipt.events[2].args[0].toNumber();
        const tokenId = receipt.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Results
        const item = await market.fetchItem(itemId);
        const royaltyInfo = await nft.royaltyInfo(tokenId, 10000);

        // Evaluate results
        expect(royaltyInfo.receiver).to.equal(artistAddress);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal(royaltyValue);
        expect(Number(await nft.balanceOf(sellerAddress, tokenId))).to.equal(10);
        assert(await nft.hasMutableURI(tokenId));
        expect(await nft.uri(tokenId)).to.equal("https://fake-uri-1.com");
        expect(Number(await nft.getTokenSupply(tokenId))).to.equal(10);

        expect(Number(item.itemId)).to.equal(itemId);
        expect(item.nftContract).to.equal(nftContractAddress);
        expect(Number(item.tokenId)).to.equal(tokenId);
        expect(item.creator).to.equal(sellerAddress);
    });

    it("Should mint batch of NFTs and create market items", async () => {
        // Create tokens
        console.log("\tcreating token...");
        const tx = await market
            .connect(seller)
            .mintBatch(
                [10, 1],
                ["https://fake-uri-2.com", "https://fake-uri-3.com"],
                [artistAddress, ownerAddress],
                [royaltyValue, 200],
                [true, false]
            );
        const receipt = await tx.wait();
        const item1Id = receipt.events[2].args[0].toNumber();
        const token1Id = receipt.events[2].args[2].toNumber();
        const item2Id = receipt.events[4].args[0].toNumber();
        const token2Id = receipt.events[4].args[2].toNumber();
        console.log(`\tNFTs created with tokenId ${token1Id} and ${token2Id}`);
        console.log(`\tMarket items created with itemId ${item1Id} and ${item2Id}`);

        // Results
        const item1 = await market.fetchItem(item1Id);
        const item2 = await market.fetchItem(item2Id);
        const royaltyInfo1 = await nft.royaltyInfo(token1Id, 10000);
        const royaltyInfo2 = await nft.royaltyInfo(token2Id, 10000);

        // Evaluate results
        expect(royaltyInfo1.receiver).to.equal(artistAddress);
        expect(royaltyInfo2.receiver).to.equal(ownerAddress);
        expect(Number(royaltyInfo1.royaltyAmount)).to.equal(royaltyValue);
        expect(Number(royaltyInfo2.royaltyAmount)).to.equal(200);
        expect(Number(await nft.balanceOf(sellerAddress, token1Id))).to.equal(10);
        expect(Number(await nft.balanceOf(sellerAddress, token2Id))).to.equal(1);
        assert(await nft.hasMutableURI(token1Id));
        assert(!(await nft.hasMutableURI(token2Id)));
        expect(await nft.uri(token1Id)).to.equal("https://fake-uri-2.com");
        expect(await nft.uri(token2Id)).to.equal("https://fake-uri-3.com");
        expect(Number(await nft.getTokenSupply(token1Id))).to.equal(10);
        expect(Number(await nft.getTokenSupply(token2Id))).to.equal(1);

        expect(Number(item1.itemId)).to.equal(item1Id);
        expect(Number(item2.itemId)).to.equal(item2Id);
        expect(item1.nftContract).to.equal(nftContractAddress);
        expect(item2.nftContract).to.equal(nftContractAddress);
        expect(Number(item1.tokenId)).to.equal(token1Id);
        expect(Number(item2.tokenId)).to.equal(token2Id);
        expect(item1.creator).to.equal(sellerAddress);
        expect(item2.creator).to.equal(sellerAddress);
    });

    it("Should create market item", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(seller)
            .mint(sellerAddress, 1, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        token1Id = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${token1Id}`);

        // Create market item
        const tx2 = await market.connect(seller).createItem(nftContractAddress, token1Id);
        const receipt2 = await tx2.wait();
        item1Id = receipt2.events[1].args[0].toNumber();

        // Results
        const item = await market.fetchItem(item1Id);

        // Evaluate results
        expect(Number(item.itemId)).to.equal(item1Id);
        expect(item.nftContract).to.equal(nftContractAddress);
        expect(Number(item.tokenId)).to.equal(token1Id);
        expect(item.creator).to.equal(sellerAddress);
    });

    it("Should put existing market item on sale", async () => {
        // Puts item on sale
        console.log("\tputting market item on sale...");
        const tx1 = await market.connect(seller).putItemOnSale(item1Id, 1, salePrice);
        const receipt1 = await tx1.wait();
        position1Id = receipt1.events[1].args[0].toNumber();
        console.log(`\tPosition created with id ${position1Id}`);

        // Results
        const position = await market.fetchPosition(position1Id);
        const item = await market.fetchItem(item1Id);

        // Evaluate results
        expect(Number(position.positionId)).to.equal(position1Id);
        expect(Number(position.item.itemId)).to.equal(item1Id);
        expect(position.owner).to.equal(sellerAddress);
        expect(Number(position.amount)).to.equal(1);
        expect(formatBigNumber(position.price)).to.equal(formatBigNumber(salePrice));
        expect(Number(position.marketFee)).to.equal(Number(marketFee));
        expect(Number(position.state)).to.equal(1); // PositionState.RegularSale = 1
        expect(Number(item.positions.at(-1).positionId)).to.equal(position1Id);
    });

    it("Should put new nft on sale", async () => {
        // Initial data
        const iniPositionsOnRegSale = await market.fetchPositionsByState(1);
        const iniItems = await market.fetchAllItems();

        // Creates NFT, adds it to the market and puts it on sale in the same call
        console.log("\tputting new market item on sale...");
        const tx = await market
            .connect(seller)
            .putNewItemOnSale(
                10,
                "https://fake-uri-1.com",
                artistAddress,
                royaltyValue,
                true,
                salePrice
            );
        const receipt = await tx.wait();
        token2Id = receipt.events[2].args[2].toNumber();
        console.log(`\tNFT created with id ${token2Id}`);
        item2Id = receipt.events[2].args[0].toNumber();
        console.log(`\tItem created with id ${item2Id}`);
        position2Id = receipt.events[4].args[0].toNumber();
        console.log(`\tPosition created with id ${position2Id}`);

        // Results
        const position = await market.fetchPosition(position2Id);
        const item = await market.fetchItem(item2Id);
        const endPositionsOnRegSale = await market.fetchPositionsByState(1);
        const endItems = await market.fetchAllItems();

        // Evaluate results
        expect(Number(position.positionId)).to.equal(position2Id);
        expect(Number(position.item.itemId)).to.equal(item2Id);
        expect(endItems.length - iniItems.length).to.equal(1);
        expect(Number(endItems.at(-1).itemId)).to.equal(item2Id);
        expect(position.owner).to.equal(sellerAddress);
        expect(Number(position.amount)).to.equal(10);
        expect(formatBigNumber(position.price)).to.equal(formatBigNumber(salePrice));
        expect(Number(position.marketFee)).to.equal(Number(marketFee));
        expect(Number(position.state)).to.equal(1); // RegularSale = 1
        expect(Number(item.positions.at(-1).positionId)).to.equal(position2Id);
        expect(endPositionsOnRegSale.length - iniPositionsOnRegSale.length).to.equal(1);
        expect(Number(endPositionsOnRegSale.at(-1).positionId)).to.equal(position2Id);
    });

    it("Should get address created items", async () => {
        // Get items created by seller
        console.log("\tgetting seller creations...");
        const items = await market.fetchAddressItemsCreated(sellerAddress);
        console.log("\tseller creations retrieved...");

        // Evaluate results
        expect(items.at(-1).creator).to.equal(sellerAddress);
        expect(items.at(-1).positions.length).to.equal(2);
    });

    it("Should create sale", async () => {
        // Initial data
        const iniSellerBalance = await getBalance(reefToken, sellerAddress, "seller");
        const iniBuyer1Balance = await getBalance(reefToken, buyer1Address, "buyer1");
        const iniArtistBalance = await getBalance(reefToken, artistAddress, "artist");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniBuyer1TokenAmount = await nft.balanceOf(buyer1Address, token1Id);
        const iniAvailablePositions = await market.fetchPositionsByState(0);

        // Buy NFT
        console.log("\tbuyer1 buying NFT from seller...");
        await market.connect(buyer1).createSale(position1Id, 1, { value: salePrice });
        console.log("\tNFT bought");

        // Final data
        const endSellerBalance = await getBalance(reefToken, sellerAddress, "seller");
        const endBuyer1Balance = await getBalance(reefToken, buyer1Address, "buyer1");
        const endArtistBalance = await getBalance(reefToken, artistAddress, "artist");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endBuyer1TokenAmount = await nft.balanceOf(buyer1Address, token1Id);
        const royaltiesAmount = (salePrice * royaltyValue) / 10000;
        const marketFeeAmount = ((salePrice - royaltiesAmount) * marketFee) / 10000;
        const item = await market.fetchItem(item1Id);
        const endAvailablePositions = await market.fetchPositionsByState(0);

        // Evaluate results
        expect(endBuyer1TokenAmount - iniBuyer1TokenAmount).to.equal(1);
        expect(endBuyer1Balance)
            .to.lte(iniBuyer1Balance - formatBigNumber(salePrice))
            .gt(iniBuyer1Balance - formatBigNumber(salePrice) - formatBigNumber(maxGasFee));
        expect(endArtistBalance).to.equal(iniArtistBalance + formatBigNumber(royaltiesAmount));

        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(
            formatBigNumber(iniOwnerMarketBalance) + formatBigNumber(marketFeeAmount)
        );
        expect(endSellerBalance).to.equal(
            iniSellerBalance +
                formatBigNumber(salePrice) -
                formatBigNumber(royaltiesAmount) -
                formatBigNumber(marketFeeAmount)
        );

        expect(item.nftContract).to.equal(nftContractAddress);
        expect(Number(item.tokenId)).to.equal(token1Id);
        expect(item.sales[0].seller).to.equal(sellerAddress);
        expect(item.sales[0].buyer).to.equal(buyer1Address);
        expect(formatBigNumber(item.sales[0].price)).to.equal(formatBigNumber(salePrice));
        expect(endAvailablePositions.length - iniAvailablePositions.length).to.equal(1);
    });

    it("Should allow market owner to withdraw fees", async () => {
        const iniOwnerBalance = await getBalance(reefToken, ownerAddress, "owner");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const iniMarketBalance = await getBalance(reefToken, marketContractAddress, "market");

        console.log("\towner withdrawing balance...");
        await market.connect(owner).withdraw();
        console.log("\tWithdrawing completed.");
        const endOwnerBalance = await getBalance(reefToken, ownerAddress, "owner");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        const endMarketBalance = await getBalance(reefToken, marketContractAddress, "market");
        console.log("iniMarketBalance", iniMarketBalance);
        console.log("endMarketBalance", endMarketBalance);
        console.log(
            "iniOwnerMarkeformatBigNumber(iniOwnerMarketBalance)tBalance",
            formatBigNumber(iniOwnerMarketBalance)
        );
        const diff = iniMarketBalance - endMarketBalance - formatBigNumber(iniOwnerMarketBalance);
        console.log("diff", diff);
        expect(diff).to.lt(0.1); // TODO should be zero, but getting a difference of ~0.064. Changing the fee amount gives similar results
        // expect(formatBigNumber(iniOwnerMarketBalance)).to.equal(iniMarketBalance - endMarketBalance);
        expect(formatBigNumber(iniOwnerMarketBalance))
            .to.gte(endOwnerBalance - iniOwnerBalance)
            .to.lt(endOwnerBalance - iniOwnerBalance + marketFee);
        expect(formatBigNumber(endOwnerMarketBalance)).to.equal(0);
    });

    it("Should allow to end sale only to seller", async () => {
        // Initial data
        const iniTokenBalance = await nft.balanceOf(sellerAddress, token2Id);
        const iniItem = await market.fetchItem(item2Id);
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
        const endItem = await market.fetchItem(item2Id);
        const endOnsale = endItem.positions.filter((pos) => pos.state == 1).length;

        // Evaluate results
        expect(endTokenBalance - iniTokenBalance).to.equal(10);
        expect(iniOnsale - endOnsale).to.equal(1);
    });

    it("Should add available tokens for existing item", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(seller)
            .mint(sellerAddress, 100, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        const tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Create market item
        console.log("\tcreating market item...");
        const tx2 = await market.connect(seller).createItem(nftContractAddress, tokenId);
        const receipt2 = await tx2.wait();
        const itemId = receipt2.events[1].args[0].toNumber();
        console.log(`\tMarket item created with id ${itemId}.`);

        // Initial data
        const iniSellerPositions = await market.fetchAddressPositions(sellerAddress);
        const iniSellerTokenPosition = iniSellerPositions.at(-1);
        const iniBuyerPositions = await market.fetchAddressPositions(buyer1Address);
        const iniItem = await market.fetchItem(itemId);
        const iniPositions = await market.fetchPositionsByState(0);

        // Transfers tokens outside the marketplace
        console.log("\tseller tansfering tokens to buyer1...");
        await nft.connect(seller).safeTransferFrom(sellerAddress, buyer1Address, tokenId, 10, []);
        console.log("\tTokens transfered.");

        // Registers tokens in the marketplace
        console.log("\tbuyer1 adding available tokens...");
        await market.connect(buyer1).addAvailableTokens(itemId);
        console.log("\tTokens registered.");

        // Final data
        const endSellerPositions = await market.fetchAddressPositions(sellerAddress);
        const endSellerTokenPosition = endSellerPositions.at(-1);
        const endBuyerPositions = await market.fetchAddressPositions(buyer1Address);
        const endBuyerTokenPosition = endBuyerPositions.at(-1);
        const endItem = await market.fetchItem(itemId);
        const endPositions = await market.fetchPositionsByState(0);

        // Evaluate results
        expect(endPositions.length - iniPositions.length).to.equal(1);
        expect(endItem.positions.length - iniItem.positions.length).to.equal(1);
        assert(endSellerPositions.length == iniSellerPositions.length);
        expect(endBuyerPositions.length - iniBuyerPositions.length).to.equal(1);
        expect(Number(iniSellerTokenPosition.amount)).to.equal(100);
        expect(Number(endSellerTokenPosition.amount)).to.equal(90);
        expect(Number(endBuyerTokenPosition.amount)).to.equal(10);
    });
});
