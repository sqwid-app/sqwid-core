const { expect } = require("chai");

exports.getBalance = async (balanceHelper, address, name) => {
    const balance = await balanceHelper.balanceOf(address);
    const balanceFormatted = Number(ethers.utils.formatUnits(balance.toString(), "ether"));
    console.log(`\t\tBalance of ${name}:`, balanceFormatted);

    return balance;
};

formatBigNumber = (bigNumber) => {
    return Number(ethers.utils.formatUnits(bigNumber.toString(), "ether"));
};

exports.throwsException = async (promise, message) => {
    try {
        await promise;
        assert(false);
    } catch (error) {
        expect(error.message).contains(message);
    }
};

exports.logEvents = async (promise) => {
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
};

exports.delay = (ms) => new Promise((res) => setTimeout(res, ms));

exports.getMainContracts = async (marketFee, owner) => {
    let nftContractAddress = config.contracts.nft;
    let marketContractAddress = config.contracts.market;
    let nft, market;

    if (!nftContractAddress || nftContractAddress == "") {
        // Deploy SqwidERC1155 contract
        console.log("\tdeploying NFT contract...");
        const NFT = await reef.getContractFactory("SqwidERC1155", owner);
        nft = await NFT.deploy();
        await nft.deployed();
        nftContractAddress = nft.address;
    } else {
        const NFT = await reef.getContractFactory("SqwidERC1155", owner);
        nft = await NFT.attach(nftContractAddress);
    }
    console.log(`\tNFT contact deployed ${nftContractAddress}`);

    if (!marketContractAddress || marketContractAddress == "") {
        // Deploy SqwidMarketplace contract
        console.log("\tdeploying Market contract...");
        const Market = await reef.getContractFactory("SqwidMarketplace", owner);
        market = await Market.deploy(marketFee, nftContractAddress);
        await market.deployed();
        marketContractAddress = market.address;
    } else {
        // Get deployed contract
        const Market = await reef.getContractFactory("SqwidMarketplace", owner);
        market = await Market.attach(marketContractAddress);
        await market.setNftContractAddress(nftContractAddress);
    }
    console.log(`\tMarket contract deployed in ${marketContractAddress}`);

    return { nft, market };
};

exports.getDummyNfts = async () => {
    let dummyERC721Address = config.contracts.dummyERC721;
    let dummyERC1155Address = config.contracts.dummyERC1155;
    let dummyERC721RoyAddress = config.contracts.dummyERC721Roy;
    let dummyERC721, dummyERC1155, dummyERC721Roy;

    if (!dummyERC721Address || dummyERC721Address == "") {
        // Deploy DummyERC721 contract
        console.log("\tdeploying DummyERC721 contract...");
        const DummyERC721 = await reef.getContractFactory("DummyERC721");
        dummyERC721 = await DummyERC721.deploy();
        await dummyERC721.deployed();
        dummyERC721Address = dummyERC721.address;
    } else {
        const DummyERC721 = await reef.getContractFactory("DummyERC721");
        dummyERC721 = await DummyERC721.attach(dummyERC721Address);
    }
    console.log(`\tDummyERC721 contact deployed ${dummyERC721Address}`);

    if (!dummyERC1155Address || dummyERC1155Address == "") {
        // Deploy DummyERC1155 contract
        console.log("\tdeploying Market contract...");
        const DummyERC1155 = await reef.getContractFactory("DummyERC1155");
        dummyERC1155 = await DummyERC1155.deploy();
        await dummyERC1155.deployed();
        dummyERC1155Address = dummyERC1155.address;
    } else {
        // Get deployed contract
        const DummyERC1155 = await reef.getContractFactory("DummyERC1155");
        dummyERC1155 = await DummyERC1155.attach(dummyERC1155Address);
    }
    console.log(`\tDummyERC1155 contract deployed in ${dummyERC1155Address}`);

    if (!dummyERC721RoyAddress || dummyERC721RoyAddress == "") {
        // Deploy DummyERC721Royalties contract
        console.log("\tdeploying Market contract...");
        const DummyERC721Roy = await reef.getContractFactory("DummyERC721Royalties");
        dummyERC721Roy = await DummyERC721Roy.deploy();
        await dummyERC721Roy.deployed();
        dummyERC721RoyAddress = dummyERC721Roy.address;
    } else {
        // Get deployed contract
        const DummyERC721Roy = await reef.getContractFactory("DummyERC721Royalties");
        dummyERC721Roy = await DummyERC721Roy.attach(dummyERC721RoyAddress);
    }
    console.log(`\tDummyERC721Roy contract deployed in ${dummyERC721RoyAddress}`);

    return { dummyERC721, dummyERC1155, dummyERC721Roy };
};

exports.getBalanceHelper = async () => {
    let balanceHelperAddress = config.contracts.balanceHelper;
    let balanceHelper;

    if (!balanceHelperAddress || balanceHelperAddress == "") {
        // Deploy BalanceHelper contract
        console.log("\tdeploying BalanceHelper contract...");
        const BalanceHelper = await reef.getContractFactory("BalanceHelper");
        balanceHelper = await BalanceHelper.deploy();
        await balanceHelper.deployed();
        balanceHelperAddress = balanceHelper.address;
    } else {
        const BalanceHelper = await reef.getContractFactory("BalanceHelper");
        balanceHelper = await BalanceHelper.attach(balanceHelperAddress);
    }
    console.log(`\tBalanceHelper contact deployed ${balanceHelperAddress}`);

    return balanceHelper;
};
