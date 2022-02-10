// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `yarn hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    console.log("starting deployment...");

    let ownerAccount;
    if (hre.network.name == "reef_testnet") {
        ownerAccount = await hre.reef.getSignerByName("account1");
    } else {
        ownerAccount = await hre.reef.getSignerByName("mainnetAccount");
    }

    // Deploy SqwidERC1155
    const NFT = await hre.reef.getContractFactory("SqwidERC1155", ownerAccount);
    const nft = await NFT.deploy();
    await nft.deployed();
    console.log(`SqwidERC1155 deployed to ${nft.address}`);

    // Deploy SqwidMarketplace
    const Marketplace = await hre.reef.getContractFactory("SqwidMarketplace", ownerAccount);
    const marketFee = 250; // 2.5%
    const mimeTypeFee = ethers.utils.parseUnits("10", "ether");
    const marketplace = await Marketplace.deploy(marketFee, mimeTypeFee, nft.address);
    await marketplace.deployed();
    console.log(`SqwidMarketplace deployed in ${marketplace.address}`);

    // Deploy SqwidMarketplaceUtil
    const MarketUtil = await hre.reef.getContractFactory("SqwidMarketplaceUtil", ownerAccount);
    const marketUtil = await MarketUtil.deploy(marketplace.address);
    await marketUtil.deployed();
    console.log(`SqwidMarketplaceUtil deployed in ${marketUtil.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
