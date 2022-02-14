const { expect } = require("chai");
const { getMainContracts, getBalanceHelper, getBalance, throwsException } = require("./util");

describe("************ Governance ******************", () => {
    before(async () => {
        governanceAddress = config.contracts.governance;

        // Get accounts
        iniOwner = await reef.getSignerByName("account1");
        owner1 = await reef.getSignerByName("account2");
        owner2 = await reef.getSignerByName("account3");
        owner3 = await reef.getSignerByName("account4");
        user1 = await reef.getSignerByName("account3");
        user2 = await reef.getSignerByName("account4");

        // Get accounts addresses
        iniOwnerAddress = await iniOwner.getAddress();
        owner1Address = await owner1.getAddress();
        owner2Address = await owner2.getAddress();
        owner3Address = await owner3.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();

        // Initialize global variables
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        royaltyValue = 1000; // 10%
        marketFee = 250;
        mimeTypeFee = ethers.utils.parseUnits("10", "ether");

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, mimeTypeFee, iniOwner);
        nft = contracts.nft;
        market = contracts.market;
        marketUtil = contracts.marketUtil;
        balanceHelper = await getBalanceHelper();

        // Deploy or get governance contract
        if (!governanceAddress || governanceAddress == "") {
            // Deploy SqwidMarketplaceUtil contract
            console.log("\tdeploying Governance contract...");
            const Governance = await reef.getContractFactory("SqwidGovernance", iniOwner);
            governance = await Governance.deploy(
                [owner1Address, owner2Address, owner3Address],
                market.address
            );
            await governance.deployed();
            governanceAddress = governance.address;
        } else {
            // Get deployed contract
            const Governance = await reef.getContractFactory("SqwidGovernance", iniOwner);
            governance = await Governance.attach(governanceAddress);
        }
        console.log(`\tGovernance contract deployed in ${governanceAddress}`);
    });

    it("Should get governance data", async () => {
        const owners = await governance.getOwners();

        expect(owners.length).to.equal(3);
        expect(owners[0]).to.equal(owner1Address);
        expect(owners[1]).to.equal(owner2Address);
        expect(owners[2]).to.equal(owner3Address);
        expect(await governance.owners(0)).to.equal(owner1Address);
        expect(await governance.owners(1)).to.equal(owner2Address);
        expect(await governance.owners(2)).to.equal(owner3Address);
        expect(await governance.marketplace()).to.equal(market.address);
    });

    it("Should transfer market ownership", async () => {
        // Initial data
        const initialOwner = await market.owner();

        // Approve market contract
        console.log("\ttransfering market ownership...");
        await market.connect(iniOwner).transferOwnership(governanceAddress);
        console.log("\tOwnership transfered.");

        // Final data
        const endOwner = await market.owner();

        // Evaluate results
        expect(initialOwner).to.equal(iniOwnerAddress);
        expect(endOwner).to.equal(governanceAddress);
    });

    it("Should set market fees", async () => {
        await throwsException(
            market.connect(iniOwner).setMarketFee(350, 1),
            "Ownable: caller is not the owner"
        );

        await throwsException(
            governance.connect(iniOwner).setMarketFee(350, 1),
            "Governance: Caller is not owner"
        );

        await governance.connect(owner1).setMarketFee(350, 1);
        let fetchedMarketFee = await market.marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(350);

        await governance.connect(owner2).setMarketFee(250, 1);
        fetchedMarketFee = await market.marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(250);
    });

    it("Should set MIME type fee", async () => {
        await governance.connect(owner2).setMimeTypeFee(mimeTypeFee.mul(2));
        let fetchedMimeFee = await market.mimeTypeFee();
        expect(Number(fetchedMimeFee)).to.equal(Number(mimeTypeFee.mul(2)));

        await governance.connect(owner3).setMimeTypeFee(mimeTypeFee);
        fetchedMimeFee = await market.mimeTypeFee();
        expect(Number(fetchedMimeFee)).to.equal(Number(mimeTypeFee));
    });

    it("Should set NFT contract address", async () => {
        await governance.connect(owner2).setNftContractAddress(iniOwnerAddress);
        let fetchedNftAddress = await market.sqwidERC1155();
        expect(fetchedNftAddress).to.equal(iniOwnerAddress);

        await governance.connect(owner3).setNftContractAddress(nft.address);
        fetchedNftAddress = await market.sqwidERC1155();
        expect(fetchedNftAddress).to.equal(nft.address);
    });

    it("Should set migrator contract address", async () => {
        await governance.connect(owner1).setMigratorAddress(iniOwnerAddress);
        let fetchedMigratorAddress = await market.sqwidMigrator();
        expect(fetchedMigratorAddress).to.equal(iniOwnerAddress);

        await governance.connect(owner3).setMigratorAddress(ethers.constants.AddressZero);
        fetchedMigratorAddress = await market.sqwidMigrator();
        expect(fetchedMigratorAddress).to.equal(ethers.constants.AddressZero);
    });

    it("Should withdraw fees from marketplace", async () => {
        // Initial data
        const salePrice = ethers.utils.parseUnits("100", "ether");
        const iniOwnerMarketBalance = await market.addressBalance(governanceAddress);

        // Approve market contract
        await nft.connect(user1).setApprovalForAll(market.address, true);
        // Create token and add to the market
        const tx1 = await market
            .connect(user1)
            .mint(1, "https://fake-uri-1.com", "image", ethers.constants.AddressZero, 0);
        const receipt1 = await tx1.wait();
        const itemId = receipt1.events[2].args[0].toNumber();
        // Puts item on sale
        const tx2 = await market.connect(user1).putItemOnSale(itemId, 1, salePrice);
        const receipt2 = await tx2.wait();
        const positionId = receipt2.events[1].args[0].toNumber();
        // Buys item
        await market.connect(user2).createSale(positionId, 1, { value: salePrice });

        // Sale results
        const feeAmount = salePrice.mul(marketFee).div(10000);
        const feeShare = feeAmount.div(3);
        const midOwnerMarketBalance = await market.addressBalance(governanceAddress);
        expect(Number(midOwnerMarketBalance.sub(iniOwnerMarketBalance))).to.equal(
            Number(feeAmount)
        );

        // External address tries to approve new market owner
        await throwsException(
            governance.connect(iniOwner).transferFromMarketplace(),
            "Governance: Caller is not owner"
        );

        // owner1 transfers funds from marketplace to governance contract
        console.log(`\ttransfering fees from marketplace...`);
        await governance.connect(owner1).transferFromMarketplace(); // TODO failed transaction
        console.log(`\tFees transfeed.`);
        expect(Number(await market.addressBalance(governanceAddress))).to.equal(0);
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.equal(
            Number(feeAmount)
        );
        expect(Number(await governance.addressBalance(owner1Address))).to.equal(Number(feeShare));
        expect(Number(await governance.addressBalance(owner2Address))).to.equal(Number(feeShare));
        expect(Number(await governance.addressBalance(owner3Address))).to.equal(Number(feeShare));

        // owner1 withdraws funds from governance contract
        const iniOwner1Balance = await getBalance(balanceHelper, owner1Address, "owner1");
        await governance.connect(owner1).withdraw();
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.equal(
            feeAmount.sub(Number(feeShare))
        );
        expect(Number(await governance.addressBalance(owner1Address))).to.equal(0);
        expect(Number(await governance.addressBalance(owner2Address))).to.equal(Number(feeShare));
        expect(Number(await governance.addressBalance(owner3Address))).to.equal(Number(feeShare));
        const endOwner1Balance = await getBalance(balanceHelper, owner1Address, "owner1");
        console.log("Net amount:", endOwner1Balance.sub(iniOwner1Balance) / 1e18); // Amount received minus gas fees

        // owner2 withdraws funds from governance contract
        const iniOwner2Balance = await getBalance(balanceHelper, owner2Address, "owner2");
        await governance.connect(owner2).withdraw();
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.equal(
            Number(feeAmount.sub(feeShare).sub(feeShare))
        );
        expect(Number(await governance.addressBalance(owner1Address))).to.equal(0);
        expect(Number(await governance.addressBalance(owner2Address))).to.equal(0);
        expect(await governance.addressBalance(owner3Address)).to.equal(feeShare);
        const endOwner2Balance = await getBalance(balanceHelper, owner2Address, "owner2");
        console.log("Net amount:", endOwner2Balance.sub(iniOwner2Balance) / 1e18); // Amount received minus gas fees

        // owner3 withdraws funds from governance contract
        const iniOwner3Balance = await getBalance(balanceHelper, owner3Address, "owner3");
        await governance.connect(owner3).withdraw();
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.lt(
            Number(ethers.utils.parseUnits("1", "ether"))
        ); // Some "wei" (smallest unit) will remain in the contract when received amount is not multiple of owners.length
        expect(Number(await governance.addressBalance(owner1Address))).to.equal(0);
        expect(Number(await governance.addressBalance(owner2Address))).to.equal(0);
        expect(Number(await governance.addressBalance(owner3Address))).to.equal(0);
        const endOwner3Balance = await getBalance(balanceHelper, owner3Address, "owner3");
        console.log("Net amount:", endOwner3Balance.sub(iniOwner3Balance) / 1e18); // Amount received minus gas fees
    });

    it("Should change market owner", async () => {
        // External address tries to approve new market owner
        await throwsException(
            governance.connect(iniOwner).approveNewMarketOwner(iniOwnerAddress),
            "Governance: Caller is not owner"
        );

        // Owner 1 approves new market owner
        await governance.connect(owner1).approveNewMarketOwner(iniOwnerAddress);
        expect(Number(await governance.marketOwnerApprovals(iniOwnerAddress))).to.equal(1);

        // Owner1 tries to approve same market owner
        await throwsException(
            governance.connect(owner1).approveNewMarketOwner(iniOwnerAddress),
            "Governance: Already approved"
        );

        // Owner 2 approves new market owner
        await governance.connect(owner2).approveNewMarketOwner(iniOwnerAddress);
        expect(Number(await governance.marketOwnerApprovals(iniOwnerAddress))).to.equal(2);

        // Owner3 tries to execute transfer ownership
        await throwsException(
            governance.connect(owner3).transferMarketplaceOwnership(iniOwnerAddress),
            "Governance: New owner not approved"
        );

        // Owner 3 approves new market owner
        await governance.connect(owner3).approveNewMarketOwner(iniOwnerAddress);
        expect(Number(await governance.marketOwnerApprovals(iniOwnerAddress))).to.equal(3);

        // Owner3 executes transfer ownership
        await governance.connect(owner3).transferMarketplaceOwnership(iniOwnerAddress);
        expect(await market.owner()).to.equal(iniOwnerAddress);
    });
});
