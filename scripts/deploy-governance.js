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

    const reef5 = await hre.reef.getSignerByName("account5");
    const reef6 = await hre.reef.getSignerByName("account6");
    const reef5Address = await reef5.getAddress();
    const reef6Address = await reef6.getAddress();

    const ownersList = [reef5Address, reef6Address];
    const minConfirmationsRequired = 1;

    const Governance = await hre.reef.getContractFactory("SqwidGovernance", ownerAccount);
    const governance = await Governance.deploy(ownersList, minConfirmationsRequired);
    await governance.deployed();
    console.log(`SqwidGovernance deployed to ${governance.address}`);
    await hre.reef.verifyContract(governance.address, "SqwidGovernance", [
        ownersList,
        minConfirmationsRequired,
    ]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
