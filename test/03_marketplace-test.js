const { expect, assert } = require("chai");
const { getMainContracts } = require("./util");

describe("************ Marketplace ******************", () => {
    let market,
        owner,
        creator,
        artist,
        marketFee,
        ownerAddress,
        creatorAddress,
        artistAddress,
        royaltyValue;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        creator = await reef.getSignerByName("account2");
        artist = await reef.getSignerByName("account3");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        creatorAddress = await creator.getAddress();
        artistAddress = await artist.getAddress();

        // Initialize global variables
        marketFee = 250; // 2.5%
        royaltyValue = 1000; // 10%

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
    });

    it("Should mint NFT and create market item", async () => {
        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(creator).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx = await market
            .connect(creator)
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
        expect(Number(await nft.balanceOf(creatorAddress, tokenId))).to.equal(10);
        assert(await nft.hasMutableURI(tokenId));
        expect(await nft.uri(tokenId)).to.equal("https://fake-uri-1.com");
        expect(Number(await nft.getTokenSupply(tokenId))).to.equal(10);

        expect(Number(item.itemId)).to.equal(itemId);
        expect(item.nftContract).to.equal(nft.address);
        expect(Number(item.tokenId)).to.equal(tokenId);
        expect(item.creator).to.equal(creatorAddress);
    });

    it("Should mint batch of NFTs and create market items", async () => {
        // Initial data
        const iniItemsCreated = await market.fetchAddressItemsCreated(creatorAddress);

        // Create tokens
        console.log("\tcreating token...");
        const tx = await market
            .connect(creator)
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
        const endItemsCreated = await market.fetchAddressItemsCreated(creatorAddress);

        // Evaluate results
        expect(royaltyInfo1.receiver).to.equal(artistAddress);
        expect(royaltyInfo2.receiver).to.equal(ownerAddress);
        expect(Number(royaltyInfo1.royaltyAmount)).to.equal(royaltyValue);
        expect(Number(royaltyInfo2.royaltyAmount)).to.equal(200);
        expect(Number(await nft.balanceOf(creatorAddress, token1Id))).to.equal(10);
        expect(Number(await nft.balanceOf(creatorAddress, token2Id))).to.equal(1);
        assert(await nft.hasMutableURI(token1Id));
        assert(!(await nft.hasMutableURI(token2Id)));
        expect(await nft.uri(token1Id)).to.equal("https://fake-uri-2.com");
        expect(await nft.uri(token2Id)).to.equal("https://fake-uri-3.com");
        expect(Number(await nft.getTokenSupply(token1Id))).to.equal(10);
        expect(Number(await nft.getTokenSupply(token2Id))).to.equal(1);

        expect(Number(item1.itemId)).to.equal(item1Id);
        expect(Number(item2.itemId)).to.equal(item2Id);
        expect(item1.nftContract).to.equal(nft.address);
        expect(item2.nftContract).to.equal(nft.address);
        expect(Number(item1.tokenId)).to.equal(token1Id);
        expect(Number(item2.tokenId)).to.equal(token2Id);
        expect(item1.creator).to.equal(creatorAddress);
        expect(item2.creator).to.equal(creatorAddress);

        expect(endItemsCreated.length - iniItemsCreated.length).to.equal(2);
        expect(endItemsCreated[0].creator).to.equal(creatorAddress);
    });

    it("Should create market item from existing NFT", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(creator)
            .mint(creatorAddress, 1, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        const tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Create market item
        const tx2 = await market.connect(creator).createItem(nft.address, tokenId);
        const receipt2 = await tx2.wait();
        const itemId = receipt2.events[1].args[0].toNumber();

        // Results
        const item = await market.fetchItem(itemId);

        // Evaluate results
        expect(Number(item.itemId)).to.equal(itemId);
        expect(item.nftContract).to.equal(nft.address);
        expect(Number(item.tokenId)).to.equal(tokenId);
        expect(item.creator).to.equal(creatorAddress);
    });

    it("Should add available tokens for existing item", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(creator)
            .mint(creatorAddress, 100, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        const tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Create market item
        console.log("\tcreating market item...");
        const tx2 = await market.connect(creator).createItem(nft.address, tokenId);
        const receipt2 = await tx2.wait();
        const itemId = receipt2.events[1].args[0].toNumber();
        console.log(`\tMarket item created with id ${itemId}.`);

        // Initial data
        const inicreatorPositions = await market.fetchAddressPositions(creatorAddress);
        const inicreatorTokenPosition = inicreatorPositions.at(-1);
        const iniArtistPositions = await market.fetchAddressPositions(artistAddress);
        const iniItem = await market.fetchItem(itemId);
        const iniPositions = await market.fetchPositionsByState(0);

        // Transfers tokens outside the marketplace
        console.log("\tcreator tansfering tokens to artist...");
        await nft.connect(creator).safeTransferFrom(creatorAddress, artistAddress, tokenId, 10, []);
        console.log("\tTokens transfered.");

        // Registers tokens in the marketplace
        console.log("\tartist adding available tokens...");
        await market.connect(artist).addAvailableTokens(itemId);
        console.log("\tTokens registered.");

        // Final data
        const endcreatorPositions = await market.fetchAddressPositions(creatorAddress);
        const endcreatorTokenPosition = endcreatorPositions.at(-1);
        const endArtistPositions = await market.fetchAddressPositions(artistAddress);
        const endArtistTokenPosition = endArtistPositions.at(-1);
        const endItem = await market.fetchItem(itemId);
        const endPositions = await market.fetchPositionsByState(0);

        // Evaluate results
        expect(endPositions.length - iniPositions.length).to.equal(1);
        expect(endItem.positions.length - iniItem.positions.length).to.equal(1);
        assert(endcreatorPositions.length == inicreatorPositions.length);
        expect(endArtistPositions.length - iniArtistPositions.length).to.equal(1);
        expect(Number(inicreatorTokenPosition.amount)).to.equal(100);
        expect(Number(endcreatorTokenPosition.amount)).to.equal(90);
        expect(Number(endArtistTokenPosition.amount)).to.equal(10);
    });
});
