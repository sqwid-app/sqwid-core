async function main() {
    console.log("starting deployment...");

    let deployerAccount;
    if (hre.network.name == "reef_testnet") {
        deployerAccount = await hre.reef.getSignerByName("account1");
    } else {
        deployerAccount = await hre.reef.getSignerByName("mainnetAccount");
    }

    // Deploy SqwidERC1155
    const NFT = await hre.reef.getContractFactory("SqwidERC1155", deployerAccount);
    const nft = await NFT.deploy();
    await nft.deployed();
    console.log(`SqwidERC1155 deployed to ${nft.address}`);
    await hre.reef.verifyContract(nft.address, "SqwidERC1155", []);

    // Deploy SqwidMarketplace
    const Marketplace = await hre.reef.getContractFactory("SqwidMarketplace", ownerAccount);
    const marketFee = 250; // 2.5%
    const marketplace = await Marketplace.deploy(marketFee, nft.address);
    await marketplace.deployed();
    console.log(`SqwidMarketplace deployed in ${marketplace.address}`);
    await hre.reef.verifyContract(marketplace.address, "SqwidMarketplace", [
        marketFee,
        nft.address,
    ]);

    // Deploy SqwidMarketplaceUtil
    const MarketUtil = await hre.reef.getContractFactory("SqwidMarketplaceUtil", ownerAccount);
    const marketUtil = await MarketUtil.deploy(marketplace.address);
    await marketUtil.deployed();
    console.log(`SqwidMarketplaceUtil deployed in ${marketUtil.address}`);
    await hre.reef.verifyContract(marketUtil.address, "SqwidMarketplaceUtil", [
        marketplace.address,
    ]);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
