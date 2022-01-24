const { expect, assert } = require("chai");

describe("************ NFT ******************", () => {
    let nft,
        nftContractAddress,
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
        // Deployed contract address (comment to deploy new contract)
        nftContractAddress = config.contracts.nft;

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

        if (!nftContractAddress || nftContractAddress == "") {
            // Deploy SqwidERC1155 contract
            console.log("\tdeploying NFT contract...");
            const NFT = await reef.getContractFactory("SqwidERC1155", contractOwner);
            const marketContractAddress =
                !config.contracts.market || config.contracts.market == ""
                    ? "0x0000000000000000000000000000000000000000"
                    : config.contracts.market;
            nft = await NFT.deploy(marketContractAddress);
            await nft.deployed();
            nftContractAddress = nft.address;
        } else {
            // Get deployed contract
            const NFT = await reef.getContractFactory("SqwidERC1155", contractOwner);
            nft = await NFT.attach(nftContractAddress);
        }
        console.log(`\tNFT contact deployed ${nftContractAddress}`);
    });

    it("Should get NFT contract data", async () => {
        const interfaceIdErc2981 = "0x2a55205a";
        const supportsErc2981 = await nft.supportsInterface(interfaceIdErc2981);

        assert(supportsErc2981);
    });

    it.only("Should create tokens", async () => {
        // Create tokens
        console.log("\tcreating tokens...");

        const tx1 = await nft
            .connect(creator)
            .mint(creatorAddress, 1, "https://fake-uri-1.com", artistAddress, royaltyValue, true);
        const receipt1 = await tx1.wait();
        token1Id = receipt1.events[0].args[3].toNumber();

        const tx2 = await nft
            .connect(creator)
            .mint(creatorAddress, 99, "https://fake-uri-2.com", artistAddress, royaltyValue, false);
        const receipt2 = await tx2.wait();
        token2Id = receipt2.events[0].args[3].toNumber();

        const tx3 = await nft
            .connect(creator)
            .mint(creatorAddress, 10, "https://fake-uri-3.com", artistAddress, royaltyValue, false);
        const receipt3 = await tx3.wait();
        token3Id = receipt3.events[0].args[3].toNumber();

        console.log(`\tNFTs created with tokenIds ${token1Id}, ${token2Id} and ${token3Id}`);

        // End data
        const royaltyInfo = await nft.royaltyInfo(token1Id, salePrice);
        const token2Supply = await nft.getTokenSupply(token2Id);

        // Evaluate results
        expect(royaltyInfo.receiver).to.equal(artistAddress);
        expect(Number(royaltyInfo.royaltyAmount)).to.equal((salePrice * royaltyValue) / 10000);
        expect(Number(await nft.balanceOf(creatorAddress, token1Id))).to.equal(1);
        expect(Number(await nft.balanceOf(creatorAddress, token2Id))).to.equal(99);
        assert(await nft.hasMutableURI(token1Id));
        expect(!(await nft.hasMutableURI(token2Id)));
        expect(await nft.uri(token1Id)).to.equal("https://fake-uri-1.com");
        expect(Number(token2Supply)).to.equal(99);
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
        [
            creatorT2Amount,
            recipientT2Amount,
            creatorT3Amount,
            recipientT3Amount,
        ] = await nft.balanceOfBatch(
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
            "SqwidERC1155: Only the owner of the total supply can set token URI."
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
            "SqwidERC1155: The metadata of this token is immutable."
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
            "ERC1155: burn amount exceeds balance"
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

    async function throwsException(promise, message) {
        try {
            await promise;
            assert(false);
        } catch (error) {
            expect(error.message).contains(message);
        }
    }

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
