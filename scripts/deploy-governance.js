async function main() {
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

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
