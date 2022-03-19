const { expect } = require("chai");
const { getMainContracts, getBalanceHelper, getBalance, throwsException } = require("./util");

describe("************ Marketplace ******************", () => {
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
        marketUtil = contracts.marketUtil;
    });

    it("Should set market fees", async () => {
        await throwsException(
            market.connect(artist).setMarketFee(350, 1),
            "Ownable: caller is not the owner"
        );

        await throwsException(
            market.connect(owner).setMarketFee(350, 0),
            "SqwidMarket: Invalid fee type"
        );

        await market.connect(owner).setMarketFee(350, 1);
        let fetchedMarketFee = await market.connect(owner).marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(350);

        await market.connect(owner).setMarketFee(250, 1);
        fetchedMarketFee = await market.connect(owner).marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(250);
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
            .mint(10, "https://fake-uri-1.com", "image", artistAddress, royaltyValue);
        const receipt = await tx.wait();
        const itemId = receipt.events[2].args[0].toNumber();
        const tokenId = receipt.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);
        console.log(`\tMarket item created with itemId ${itemId}`);

        // Results
        const item = await marketUtil.fetchItem(itemId);
        const royaltyInfo = await nft.royaltyInfo(tokenId, 10000);

        // Evaluate results
        expect(royaltyInfo.receiver).to.equal(artistAddress);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal(royaltyValue);
        expect(Number(await nft.balanceOf(creatorAddress, tokenId))).to.equal(10);
        expect(await nft.uri(tokenId)).to.equal("https://fake-uri-1.com");
        expect(await nft.mimeType(tokenId)).to.equal("image");
        expect(Number(await nft.getTokenSupply(tokenId))).to.equal(10);

        expect(Number(item.itemId)).to.equal(itemId);
        expect(item.nftContract).to.equal(nft.address);
        expect(Number(item.tokenId)).to.equal(tokenId);
        expect(item.creator).to.equal(creatorAddress);
    });

    it("Should mint batch of NFTs and create market items", async () => {
        // Initial data
        const iniNumItemsCreated = Number(
            await marketUtil.fetchAddressNumberItemsCreated(creatorAddress)
        );

        // Create tokens
        console.log("\tcreating token...");
        const tx = await market
            .connect(creator)
            .mintBatch(
                [10, 1],
                ["https://fake-uri-2.com", "https://fake-uri-3.com"],
                ["video", "other"],
                [artistAddress, ownerAddress],
                [royaltyValue, 200]
            );
        const receipt = await tx.wait();
        const item1Id = receipt.events[2].args[0].toNumber();
        const token1Id = receipt.events[2].args[2].toNumber();
        const item2Id = receipt.events[4].args[0].toNumber();
        const token2Id = receipt.events[4].args[2].toNumber();
        console.log(`\tNFTs created with tokenId ${token1Id} and ${token2Id}`);
        console.log(`\tMarket items created with itemId ${item1Id} and ${item2Id}`);

        // Results
        const item1 = await marketUtil.fetchItem(item1Id);
        const item2 = await marketUtil.fetchItem(item2Id);
        const royaltyInfo1 = await nft.royaltyInfo(token1Id, 10000);
        const royaltyInfo2 = await nft.royaltyInfo(token2Id, 10000);
        const endNumItemsCreated = Number(
            await marketUtil.fetchAddressNumberItemsCreated(creatorAddress)
        );

        // Evaluate results
        expect(royaltyInfo1.receiver).to.equal(artistAddress);
        expect(royaltyInfo2.receiver).to.equal(ownerAddress);
        expect(Number(royaltyInfo1.royaltyAmount)).to.equal(royaltyValue);
        expect(Number(royaltyInfo2.royaltyAmount)).to.equal(200);
        expect(Number(await nft.balanceOf(creatorAddress, token1Id))).to.equal(10);
        expect(Number(await nft.balanceOf(creatorAddress, token2Id))).to.equal(1);
        expect(await nft.uri(token1Id)).to.equal("https://fake-uri-2.com");
        expect(await nft.uri(token2Id)).to.equal("https://fake-uri-3.com");
        expect(await nft.mimeType(token1Id)).to.equal("video");
        expect(await nft.mimeType(token2Id)).to.equal("other");
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

        expect(endNumItemsCreated - iniNumItemsCreated).to.equal(2);
    });

    it("Should create market item from existing NFT", async () => {
        // Create token
        console.log("\tcreating token...");
        const tx1 = await nft
            .connect(creator)
            .mint(
                creatorAddress,
                1,
                "https://fake-uri-1.com",
                "image",
                artistAddress,
                royaltyValue
            );
        const receipt1 = await tx1.wait();
        const tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Create market item
        const tx2 = await market.connect(creator).createItem(tokenId);
        const receipt2 = await tx2.wait();
        const itemId = receipt2.events[1].args[0].toNumber();

        // Tries to create same item
        await throwsException(
            market.connect(creator).createItem(tokenId),
            "SqwidMarketplace: Item already exists"
        );

        // Results
        const item = await marketUtil.fetchItem(itemId);

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
            .mint(
                creatorAddress,
                100,
                "https://fake-uri-1.com",
                "image",
                artistAddress,
                royaltyValue
            );
        const receipt1 = await tx1.wait();
        const tokenId = receipt1.events[0].args[3].toNumber();
        console.log(`\tNFT created with tokenId ${tokenId}`);

        // Create market item
        console.log("\tcreating market item...");
        const tx2 = await market.connect(creator).createItem(tokenId);
        const receipt2 = await tx2.wait();
        const itemId = receipt2.events[1].args[0].toNumber();
        console.log(`\tMarket item created with id ${itemId}.`);

        // Initial data
        const iniNumCreatorPositions = Number(
            await marketUtil.fetchAddressNumberPositions(creatorAddress)
        );
        const iniNumArtistPositions = Number(
            await marketUtil.fetchAddressNumberPositions(artistAddress)
        );
        const iniItem = await marketUtil.fetchItem(itemId);
        const iniNumPositions = Number(await market.fetchStateCount(0));

        // Transfers tokens outside the marketplace
        console.log("\tcreator tansfering tokens to artist...");
        await nft.connect(creator).safeTransferFrom(creatorAddress, artistAddress, tokenId, 10, []);
        console.log("\tTokens transfered.");

        // Registers tokens in the marketplace
        console.log("\tartist adding available tokens...");
        await market.connect(artist).addAvailableTokens(itemId);
        console.log("\tTokens registered.");

        // Tries to register tokens again
        await throwsException(
            market.connect(artist).addAvailableTokens(itemId),
            "SqwidMarket: Item already registered"
        );

        // Final data
        const endNumCreatorPositions = Number(
            await marketUtil.fetchAddressNumberPositions(creatorAddress)
        );
        const endNumArtistPositions = Number(
            await marketUtil.fetchAddressNumberPositions(artistAddress)
        );
        const endItem = await marketUtil.fetchItem(itemId);
        const endNumPositions = Number(await market.fetchStateCount(0));

        // Evaluate results
        expect(endNumPositions - iniNumPositions).to.equal(1);
        expect(endItem.positions.length - iniItem.positions.length).to.equal(1);
        expect(endNumCreatorPositions).to.equal(iniNumCreatorPositions);
        expect(endNumArtistPositions - iniNumArtistPositions).to.equal(1);
    });

    it("Should create great amount of market items", async () => {
        balanceHelper = await getBalanceHelper();

        // Initial data
        const iniItemsCreated = Number(
            await marketUtil.fetchAddressNumberItemsCreated(creatorAddress)
        );

        const ITEM_START = 100;
        const NUM_ITEMS = 35;
        const BASE_URI = "ipfs://QmQAoMbqJsfxUSLZZwS3zG34nGkWtPhXoXk7itrqC9Tb1q/sqwid-0{id}.json";

        // Create tokens
        console.log("\tcreating token...");
        const units = [];
        const uris = [];
        const mimes = [];
        const artistAddrs = [];
        const royalties = [];
        for (let i = ITEM_START; i < ITEM_START + NUM_ITEMS; i++) {
            units.push(1);
            uris.push(BASE_URI.replace("{id}", String(i).padStart(4, "0")));
            mimes.push("image");
            artistAddrs.push(artistAddress);
            royalties.push(royaltyValue);
        }

        console.log("creating from " + ITEM_START + " to " + (ITEM_START + NUM_ITEMS - 1));
        await getBalance(balanceHelper, creatorAddress, "creator");

        const tx = await market
            .connect(creator)
            .mintBatch(units, uris, mimes, artistAddrs, royalties);
        const receipt = await tx.wait();

        await getBalance(balanceHelper, creatorAddress, "creator");

        for (let i = 2; i < receipt.events.length; i += 2) {
            const itemId = receipt.events[i].args[0].toNumber();
            // console.log(`\tMarket item created with itemId ${itemId}`);
        }

        const endItemsCreated = Number(
            await marketUtil.fetchAddressNumberItemsCreated(creatorAddress)
        );

        expect(endItemsCreated - iniItemsCreated).to.equal(NUM_ITEMS);
    });
});
