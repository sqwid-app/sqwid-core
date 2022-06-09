const { expect, assert } = require("chai");
const { getMainContracts, getDummyNfts, throwsException } = require("./util");

describe("************ Wrapper ******************", () => {
    let wrappedToken1Id, wrappedToken2Id;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        user1 = await reef.getSignerByName("account2");
        user2 = await reef.getSignerByName("account3");
        user3 = await reef.getSignerByName("account4");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();

        // Initialize global variables
        marketFee = 250; // 2.5%
        royaltyValue = 2000; // 20%
        token2Amount = 99;

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        sqwidNft = contracts.nft;
        const dummyNftContract = await getDummyNfts();
        dummyERC721 = dummyNftContract.dummyERC721;
        dummyERC1155 = dummyNftContract.dummyERC1155;
        dummyERC721Royalties = dummyNftContract.dummyERC721Roy;
        dummyERC721Address = dummyERC721.address;
        dummyERC1155Address = dummyERC1155.address;
        dummyERC721RoyaltiesAddress = dummyERC721Royalties.address;

        // Create dummy NFTs
        console.log(`\tcreating dummy tokens...`);
        const tx1 = await dummyERC721.connect(user1).mint(user1Address, "fake-uri-1");
        const receipt1 = await tx1.wait();
        token1Id = Number(receipt1.events[0].args.tokenId);
        console.log(`\tToken 1 id: ${token1Id}`);

        const tx2 = await dummyERC1155.connect(user2).mint(user2Address, token2Amount);
        const receipt2 = await tx2.wait();
        token2Id = Number(receipt2.events[0].args[3]);
        console.log(`\tToken 2 id: ${token2Id}`);

        // Set approval for nft contracts
        await dummyERC721.connect(user1).setApprovalForAll(sqwidNft.address, true);
        await dummyERC1155.connect(user2).setApprovalForAll(sqwidNft.address, true);
        await dummyERC1155.connect(user3).setApprovalForAll(sqwidNft.address, true);
        await dummyERC721Royalties.connect(user1).setApprovalForAll(sqwidNft.address, true);
    });

    it("Should not allow to wrap ERC721 if is not owner", async () => {
        console.log("\twrapping token 1...");
        await throwsException(
            sqwidNft.connect(user2).wrapERC721(dummyERC721Address, token1Id, "image"),
            "ERC1155: Sender is not token owner"
        );
    });

    it("Should wrap ERC721", async () => {
        console.log("\twrapping token 1...");
        const tx1 = await sqwidNft.connect(user1).wrapERC721(dummyERC721Address, token1Id, "image");
        const receipt1 = await tx1.wait();
        wrappedToken1Id = receipt1.events[2].args[3];
        console.log(`\tToken wrapped into token ${wrappedToken1Id}.`);

        const wrappedToken = await sqwidNft.getWrappedToken(wrappedToken1Id);
        const royaltyInfo = await sqwidNft.royaltyInfo(wrappedToken1Id, 10000);

        // Original token
        expect(await dummyERC721.ownerOf(token1Id)).to.equal(sqwidNft.address);
        // Wrapped token
        expect(Number(wrappedToken.tokenId)).to.equal(Number(wrappedToken1Id));
        assert(wrappedToken.isErc721);
        expect(Number(wrappedToken.extTokenId)).to.equal(token1Id);
        expect(wrappedToken.extNftContract).to.equal(dummyERC721Address);
        expect(await sqwidNft.uri(wrappedToken1Id)).to.equal(await dummyERC721.tokenURI(token1Id));
        expect(await sqwidNft.mimeType(wrappedToken1Id)).to.equal("image");
        expect(Number(await sqwidNft.getTokenSupply(wrappedToken1Id))).to.equal(1);
        expect(Number(await sqwidNft.balanceOf(user1Address, wrappedToken1Id)), 1);
        expect(royaltyInfo.receiver).to.equal(ethers.constants.AddressZero);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal(0);
    });

    it("Should not allow to unwrap ERC721 if is not owner", async () => {
        console.log("\tunwrapping token 1...");
        await throwsException(
            sqwidNft.connect(user2).unwrapERC721(wrappedToken1Id),
            "ERC1155: Not token owned to unwrap"
        );
    });

    it("Should not allow to unwrap ERC721 if token sent is ERC1155", async () => {
        // Create dummy ERC1155 token
        console.log(`\tcreating dummy ERC1155 token...`);
        const tx1 = await dummyERC1155.connect(user2).mint(user2Address, 1);
        const receipt1 = await tx1.wait();
        const tokenId = Number(receipt1.events[0].args[3]);
        console.log(`\tToken id: ${tokenId}`);

        console.log("\twrapping ERC1155 token...");
        const tx2 = await sqwidNft
            .connect(user2)
            .wrapERC1155(dummyERC1155Address, tokenId, "image", 1);
        const receipt2 = await tx2.wait();
        const wrappedTokenId = receipt2.events[1].args[3];
        console.log(`\tToken wrapped into token ${wrappedTokenId}.`);

        console.log("\tunwrapping ERC721 token...");
        await throwsException(
            sqwidNft.connect(user2).unwrapERC721(wrappedTokenId),
            "ERC1155: Token is not ERC721"
        );
    });

    it("Should unwrap ERC721", async () => {
        console.log("\tunwrapping token 1...");
        await sqwidNft.connect(user1).unwrapERC721(wrappedToken1Id);
        console.log(`\tToken unwrapped.`);

        // Original token
        expect(await dummyERC721.ownerOf(token1Id)).to.equal(user1Address);
        // Wrapped token
        expect(Number(await sqwidNft.getTokenSupply(wrappedToken1Id))).to.equal(0);
        expect(Number(await sqwidNft.balanceOf(user1Address, wrappedToken1Id)), 0);
    });

    it("Should not allow to wrap ERC1155 has not enough balance", async () => {
        console.log("\twrapping token 2...");
        await throwsException(
            sqwidNft.connect(user1).wrapERC1155(dummyERC1155Address, token2Id, "image", 100),
            "ERC1155: Not enough tokens owned"
        );
    });

    it("Should wrap ERC1155", async () => {
        console.log("\twrapping 10 units of token 2...");
        const tx1 = await sqwidNft
            .connect(user2)
            .wrapERC1155(dummyERC1155Address, token2Id, "video", 10);
        const receipt1 = await tx1.wait();
        wrappedToken2Id = receipt1.events[1].args[3];
        console.log(`\tToken wrapped into token ${wrappedToken2Id}.`);

        const wrappedToken = await sqwidNft.getWrappedToken(wrappedToken2Id);
        const royaltyInfo = await sqwidNft.royaltyInfo(wrappedToken2Id, 10000);

        // Original token
        expect(Number(await dummyERC1155.balanceOf(user2Address, token2Id))).to.equal(
            token2Amount - 10
        );
        expect(Number(await dummyERC1155.balanceOf(sqwidNft.address, token2Id))).to.equal(10);
        // Wrapped token
        expect(Number(wrappedToken.tokenId)).to.equal(Number(wrappedToken2Id));
        assert(!wrappedToken.isErc721);
        expect(Number(wrappedToken.extTokenId)).to.equal(token2Id);
        expect(wrappedToken.extNftContract).to.equal(dummyERC1155Address);
        expect(await sqwidNft.uri(wrappedToken2Id)).to.equal(await dummyERC1155.uri(token2Id));
        expect(await sqwidNft.mimeType(wrappedToken2Id)).to.equal("video");
        expect(Number(await sqwidNft.getTokenSupply(wrappedToken2Id))).to.equal(10);
        expect(Number(await sqwidNft.balanceOf(user2Address, wrappedToken2Id)), 10);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal(0);
    });

    it("Should not allow to unwrap ERC1155 if is not owner", async () => {
        console.log("\tunwrapping token 2...");
        await throwsException(
            sqwidNft.connect(user1).unwrapERC1155(wrappedToken1Id),
            "ERC1155: Not enough tokens owner"
        );
    });

    it("Should not allow to unwrap ERC1155 if token sent is ERC721", async () => {
        // Create dummy ERC721 token
        console.log(`\tcreating dummy ERC721 token...`);
        const tx1 = await dummyERC721.connect(user1).mint(user1Address, "fake-uri");
        const receipt1 = await tx1.wait();
        const tokenId = Number(receipt1.events[0].args.tokenId);
        console.log(`\tToken id: ${tokenId}`);

        console.log("\twrapping ERC721 token...");
        const tx2 = await sqwidNft.connect(user1).wrapERC721(dummyERC721Address, tokenId, "image");
        const receipt2 = await tx2.wait();
        const wrappedTokenId = receipt2.events[2].args[3];
        console.log(`\tToken wrapped into token ${wrappedTokenId}.`);

        console.log("\tunwrapping ERC1155 token...");
        await throwsException(
            sqwidNft.connect(user1).unwrapERC1155(wrappedTokenId),
            "ERC1155: Token is not ERC1155"
        );
    });

    it("Should unwrap ERC1155", async () => {
        console.log("\tunwrapping token 2...");
        await sqwidNft.connect(user2).unwrapERC1155(wrappedToken2Id);
        console.log(`\tToken unwrapped.`);

        // Original token
        expect(Number(await dummyERC1155.balanceOf(user2Address, token2Id))).to.equal(token2Amount);
        expect(Number(await dummyERC1155.balanceOf(sqwidNft.address, token2Id))).to.equal(0);
        // Wrapped token
        expect(Number(await sqwidNft.getTokenSupply(wrappedToken2Id))).to.equal(0);
        expect(Number(await sqwidNft.balanceOf(user2Address, wrappedToken2Id)), 0);
    });

    it("Should wrap ERC1155 tokens from multiple users", async () => {
        console.log("\ttransfering 5 units of tokens 2 to user 3...");
        await dummyERC1155
            .connect(user2)
            .safeTransferFrom(user2Address, user3Address, token2Id, 5, "0x");

        console.log("\tuser 2 wrapping 20 units of token 2...");
        await sqwidNft.connect(user2).wrapERC1155(dummyERC1155Address, token2Id, "audio", 20);

        console.log("\tuser 2 wrapping 10 units more...");
        await sqwidNft.connect(user2).wrapERC1155(dummyERC1155Address, token2Id, "image", 10);

        console.log("\tuser 3 wrapping 5 units...");
        await sqwidNft.connect(user3).wrapERC1155(dummyERC1155Address, token2Id, "other", 5);

        const wrappedToken = await sqwidNft.getWrappedToken(wrappedToken2Id);

        // Original token
        expect(Number(await dummyERC1155.balanceOf(user2Address, token2Id))).to.equal(
            token2Amount - 20 - 10 - 5
        );
        expect(Number(await dummyERC1155.balanceOf(user3Address, token2Id))).to.equal(0);
        expect(Number(await dummyERC1155.balanceOf(sqwidNft.address, token2Id))).to.equal(
            20 + 5 + 10
        );
        // Wrapped token
        expect(Number(wrappedToken.tokenId)).to.equal(Number(wrappedToken2Id));
        assert(!wrappedToken.isErc721);
        expect(Number(wrappedToken.extTokenId)).to.equal(token2Id);
        expect(wrappedToken.extNftContract).to.equal(dummyERC1155Address);
        expect(await sqwidNft.uri(wrappedToken2Id)).to.equal(await dummyERC1155.uri(token2Id));
        expect(await sqwidNft.mimeType(wrappedToken2Id)).to.equal("video");
        expect(Number(await sqwidNft.getTokenSupply(wrappedToken2Id))).to.equal(20 + 5 + 10);
        expect(Number(await sqwidNft.balanceOf(user2Address, wrappedToken2Id)), 20 + 10);
        expect(Number(await sqwidNft.balanceOf(user3Address, wrappedToken2Id)), 5);
    });

    it("Should wrap tokens with royalties support", async () => {
        console.log(`\tcreating token with royalties...`);
        const tx1 = await dummyERC721Royalties
            .connect(user3)
            .mint(user1Address, "fake-uri", user3Address, royaltyValue);
        const receipt1 = await tx1.wait();
        const tokenId = Number(receipt1.events[0].args.tokenId);
        console.log(`\tToken id: ${tokenId}`);

        expect(await dummyERC721Royalties.ownerOf(tokenId)).to.equal(user1Address);

        console.log("\twrapping token with royalties...");
        const tx2 = await sqwidNft
            .connect(user1)
            .wrapERC721(dummyERC721RoyaltiesAddress, tokenId, "model");
        const receipt2 = await tx2.wait();
        const wrappedTokenId = receipt2.events[2].args[3];
        console.log(`\tToken wrapped into token ${wrappedTokenId}.`);

        const royaltyInfo = await sqwidNft.royaltyInfo(wrappedTokenId, 10000);

        expect(royaltyInfo.receiver).to.equal(user3Address);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal(royaltyValue);
    });
});
