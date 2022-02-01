const { expect, assert } = require("chai");
const { getContracts, throwsException } = require("./util");

describe("************ NFT ******************", () => {
    let nft,
        contractOwner,
        artist,
        creator,
        token1Id,
        token2Id,
        token3Id,
        royaltyValue,
        newTokenURI,
        salePrice,
        creatorAddress,
        artistAddress;

    before(async () => {
        // Get accounts
        contractOwner = await reef.getSignerByName("account1");
        creator = await reef.getSignerByName("account2");
        artist = await reef.getSignerByName("account3");
        recipient = await reef.getSignerByName("account4");

        // Get accounts addresses
        creatorAddress = await creator.getAddress();
        artistAddress = await artist.getAddress();
        recipientAddress = await recipient.getAddress();

        // Initialize global variables
        newTokenURI = "https://fake-uri-xyz.com";
        salePrice = ethers.utils.parseUnits("50", "ether");
        royaltyValue = 1000; // 10%

        // Deploy or get existing contracts
        const contracts = await getContracts(250, contractOwner);
        nft = contracts.nft;
    });

    it("Should get NFT contract data", async () => {
        const interfaceIdErc2981 = "0x2a55205a";
        const supportsErc2981 = await nft.supportsInterface(interfaceIdErc2981);

        assert(supportsErc2981);
    });

    it("Should create tokens", async () => {
        // Create tokens
        console.log("\tcreating tokens...");

        const tx1 = await nft
            .connect(creator)
            .mint(creatorAddress, 1, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        token1Id = receipt1.events[0].args[3].toNumber();

        const tx2 = await nft
            .connect(creator)
            .mintBatch(
                creatorAddress,
                [99, 10],
                ["https://fake-uri-2.com", "https://fake-uri-3.com"],
                [artistAddress, artistAddress],
                [royaltyValue, royaltyValue],
                [false, false]
            );
        const receipt2 = await tx2.wait();
        token2Id = receipt2.events[0].args[3][0].toNumber();
        token3Id = receipt2.events[0].args[3][1].toNumber();

        console.log(`\tNFTs created with tokenIds ${token1Id}, ${token2Id} and ${token3Id}`);

        // End data
        const royaltyInfo1 = await nft.royaltyInfo(token1Id, salePrice);
        const royaltyInfo2 = await nft.royaltyInfo(token2Id, salePrice);
        const royaltyInfo3 = await nft.royaltyInfo(token3Id, salePrice);
        const token1Supply = await nft.getTokenSupply(token1Id);
        const token2Supply = await nft.getTokenSupply(token2Id);
        const token3Supply = await nft.getTokenSupply(token3Id);

        // Evaluate results
        expect(royaltyInfo1.receiver).to.equal(artistAddress);
        expect(royaltyInfo2.receiver).to.equal(artistAddress);
        expect(royaltyInfo3.receiver).to.equal(artistAddress);
        expect(Number(royaltyInfo1.royaltyAmount)).to.equal((salePrice * royaltyValue) / 10000);
        expect(Number(royaltyInfo2.royaltyAmount)).to.equal((salePrice * royaltyValue) / 10000);
        expect(Number(royaltyInfo3.royaltyAmount)).to.equal((salePrice * royaltyValue) / 10000);
        expect(Number(await nft.balanceOf(creatorAddress, token1Id))).to.equal(1);
        expect(Number(await nft.balanceOf(creatorAddress, token2Id))).to.equal(99);
        expect(Number(await nft.balanceOf(creatorAddress, token3Id))).to.equal(10);
        assert(await nft.hasMutableURI(token1Id));
        expect(!(await nft.hasMutableURI(token2Id)));
        expect(await nft.hasMutableURI(token3Id));
        expect(await nft.uri(token1Id)).to.equal("https://fake-uri-1.com");
        expect(await nft.uri(token2Id)).to.equal("https://fake-uri-2.com");
        expect(await nft.uri(token3Id)).to.equal("https://fake-uri-3.com");
        expect(Number(token1Supply)).to.equal(1);
        expect(Number(token2Supply)).to.equal(99);
        expect(Number(token3Supply)).to.equal(10);
    });

    it("Should transfer single token", async () => {
        // Transfer token
        console.log("\ttransfering token...");
        await nft
            .connect(creator)
            .safeTransferFrom(creatorAddress, recipientAddress, token1Id, 1, []);
        console.log("\tToken transfered");

        expect(Number(await nft.balanceOf(creatorAddress, token1Id))).to.equal(0);
        expect(Number(await nft.balanceOf(recipientAddress, token1Id))).to.equal(1);
    });

    it("Should transfer multiple tokens", async () => {
        // Transfer token
        console.log("\ttransfering tokens...");
        await nft
            .connect(creator)
            .safeBatchTransferFrom(
                creatorAddress,
                recipientAddress,
                [token2Id, token3Id],
                [9, 3],
                []
            );
        console.log("\tTokens transfered");

        // Final data
        [creatorT2Amount, recipientT2Amount, creatorT3Amount, recipientT3Amount] =
            await nft.balanceOfBatch(
                [creatorAddress, recipientAddress, creatorAddress, recipientAddress],
                [token2Id, token2Id, token3Id, token3Id]
            );
        const token2Owners = await nft.getOwners(token2Id);

        expect(Number(creatorT2Amount)).to.equal(90);
        expect(Number(recipientT2Amount)).to.equal(9);
        expect(Number(creatorT3Amount)).to.equal(7);
        expect(Number(recipientT3Amount)).to.equal(3);
        expect(token2Owners.length).to.equal(2);
        assert(token2Owners.includes(creatorAddress));
        assert(token2Owners.includes(recipientAddress));
    });

    it("Should not change tokenURI if caller is not owner of total token supply", async () => {
        // Creates new token
        const tx = await nft
            .connect(creator)
            .mint(creatorAddress, 10, "https://fake-uri.com", artistAddress, royaltyValue, true);
        const receipt = await tx.wait();
        const tokenId = receipt.events[0].args[3].toNumber();

        // Transfer token
        console.log("\ttransfering token...");
        await nft
            .connect(creator)
            .safeTransferFrom(creatorAddress, recipientAddress, tokenId, 1, []);
        console.log("\tToken transfered");

        // Change tokenURI
        console.log("\tcreator changing tokenURI...");
        await throwsException(
            nft.connect(creator).setTokenUri(token1Id, newTokenURI),
            "ERC1155: Only owner can set URI"
        );
    });

    it("Should not change tokenURI if token is not mutable", async () => {
        // Creates new token
        const tx = await nft
            .connect(creator)
            .mint(creatorAddress, 10, "https://fake-uri.com", artistAddress, royaltyValue, false);
        const receipt = await tx.wait();
        const tokenId = receipt.events[0].args[3].toNumber();

        // Change tokenURI
        console.log("\tcreator changing tokenURI...");
        await throwsException(
            nft.connect(creator).setTokenUri(tokenId, newTokenURI),
            "ERC1155: Token metadata is immutable"
        );
    });

    it("Should change tokenURI", async () => {
        // Creates new token
        const tx = await nft
            .connect(creator)
            .mint(creatorAddress, 10, "https://fake-uri.com", artistAddress, royaltyValue, true);
        const receipt = await tx.wait();
        const tokenId = receipt.events[0].args[3].toNumber();

        // Change tokenURI
        console.log("\tcreator changing tokenURI...");

        // Change tokenURI
        console.log("\tcreator changing tokenURI...");
        await nft.connect(creator).setTokenUri(tokenId, newTokenURI);
        console.log("\ttokenURI changed.");

        // Final data
        const endTokenURI = await nft.uri(tokenId);

        expect(endTokenURI).to.equal(newTokenURI);
    });

    it("Should not burn token if is not owner", async () => {
        console.log("\tcreator burning token...");
        await throwsException(
            nft.connect(creator).burn(creatorAddress, token1Id, 1),
            "ERC1155: Burn amount exceeds balance"
        );
    });

    it("Should burn token", async () => {
        const iniToken2Supply = await nft.getTokenSupply(token2Id);

        console.log("\tcreator burning token...");
        await nft.connect(creator).burn(creatorAddress, token2Id, 10);

        const endToken2Supply = await nft.getTokenSupply(token2Id);

        expect(iniToken2Supply - endToken2Supply).to.equal(10);
    });

    it("Should burn multiple tokens", async () => {
        const iniToken2Supply = await nft.getTokenSupply(token2Id);
        const iniToken3Supply = await nft.getTokenSupply(token3Id);

        console.log("\tcreator burning token...");
        await nft.connect(creator).burnBatch(creatorAddress, [token2Id, token3Id], [10, 1]);

        const endToken2Supply = await nft.getTokenSupply(token2Id);
        const endToken3Supply = await nft.getTokenSupply(token3Id);

        expect(iniToken2Supply - endToken2Supply).to.equal(10);
        expect(iniToken3Supply - endToken3Supply).to.equal(1);
    });
});
