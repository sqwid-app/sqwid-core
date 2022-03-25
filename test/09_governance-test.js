const { expect, assert } = require("chai");
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

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, iniOwner);
        nft = contracts.nft;
        market = contracts.market;
        marketUtil = contracts.marketUtil;
        balanceHelper = await getBalanceHelper();

        // Deploy or get governance contract
        const Governance = await reef.getContractFactory("SqwidGovernance", iniOwner);
        if (!governanceAddress || governanceAddress == "") {
            // Deploy SqwidMarketplaceUtil contract
            console.log("\tdeploying Governance contract...");
            governance = await Governance.deploy([owner1Address, owner2Address, owner3Address], 2);
            await governance.deployed();
            governanceAddress = governance.address;
        } else {
            // Get deployed contract
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
        expect(Number(await governance.minConfirmationsRequired())).to.equal(2);
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

        // Change regular sale market fee to 350
        const encodedFunctionCall1 = market.interface.encodeFunctionData("setMarketFee", [350, 1]);
        const tx1 = await governance
            .connect(owner1)
            .proposeTransaction(market.address, 0, encodedFunctionCall1);
        const receipt1 = await tx1.wait();
        const transactionIndex1 = receipt1.events[0].args.txIndex;
        await governance.connect(owner2).approveTransaction(transactionIndex1);
        await governance.connect(owner3).executeTransaction(transactionIndex1);

        let fetchedMarketFee = await market.marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(350);

        // Change regular sale market fee back to 250
        const encodedFunctionCall2 = market.interface.encodeFunctionData("setMarketFee", [250, 1]);
        const tx2 = await governance
            .connect(owner1)
            .proposeTransaction(market.address, 0, encodedFunctionCall2);
        const receipt2 = await tx2.wait();
        const transactionIndex2 = receipt2.events[0].args.txIndex;
        await governance.connect(owner2).approveTransaction(transactionIndex2);
        await governance.connect(owner3).executeTransaction(transactionIndex2);

        fetchedMarketFee = await market.marketFees(1);
        expect(Number(fetchedMarketFee)).to.equal(250);
    });

    it("Should withdraw fees from marketplace", async () => {
        // Remove pending funds from previous tests
        if (Number(await governance.addressBalance(owner1Address))) {
            await governance.connect(owner1).withdraw();
        }
        if (Number(await governance.addressBalance(owner2Address))) {
            await governance.connect(owner2).withdraw();
        }
        if (Number(await governance.addressBalance(owner3Address))) {
            await governance.connect(owner3).withdraw();
        }

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
            governance.connect(iniOwner).transferFromMarketplace(market.address),
            "Governance: Caller is not owner"
        );

        // owner1 transfers funds from marketplace to governance contract
        await governance.connect(owner1).transferFromMarketplace(market.address);
        expect(Number(await market.addressBalance(governanceAddress))).to.equal(0);
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.equal(
            Number(feeAmount)
        );

        // owner1 withdraws funds from governance contract
        const iniOwner1Balance = await getBalance(balanceHelper, owner1Address, "owner1");
        await governance.connect(owner1).withdraw();
        expect(Number(await getBalance(balanceHelper, governanceAddress, ""))).to.equal(
            Number(feeAmount.sub(feeShare))
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
        expect(Number(await governance.addressBalance(owner3Address))).to.equal(Number(feeShare));
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

    it("Should add new owner", async () => {
        const tx = await governance.connect(owner1).proposeOwnersChange(iniOwnerAddress, true);
        const index = (await tx.wait()).events[0].args.ownersChangeIndex;
        await governance.connect(owner2).approveOwnersChange(index);
        await governance.connect(owner1).executeOwnersChange(index);

        const owners = await governance.getOwners();
        expect(owners.length).to.equal(4);
        expect(owners[3]).to.equal(iniOwnerAddress);
    });

    it("Should remove owner", async () => {
        const tx = await governance.connect(owner1).proposeOwnersChange(iniOwnerAddress, false);
        const index = (await tx.wait()).events[0].args.ownersChangeIndex;
        await governance.connect(iniOwner).approveOwnersChange(index);
        await governance.connect(owner1).executeOwnersChange(index);

        const owners = await governance.getOwners();
        expect(owners.length).to.equal(3);
        assert(!owners.find((o) => o == iniOwnerAddress));
    });

    it("Should modify minimum confirmations", async () => {
        const tx = await governance.connect(owner1).proposeMinConfirmationsChange(3);
        const index = (await tx.wait()).events[0].args.minConfirmationsChangeIndex;
        await governance.connect(owner3).approveMinConfirmationsChange(index);
        await governance.connect(owner2).executeMinConfirmationsChange(index);

        expect(Number(await governance.minConfirmationsRequired())).to.equal(3);

        const tx2 = await governance.connect(owner1).proposeMinConfirmationsChange(2);
        const index2 = (await tx2.wait()).events[0].args.minConfirmationsChangeIndex;
        await governance.connect(owner2).approveMinConfirmationsChange(index2);
        await governance.connect(owner3).approveMinConfirmationsChange(index2);
        await governance.connect(owner1).executeMinConfirmationsChange(index2);

        expect(Number(await governance.minConfirmationsRequired())).to.equal(2);
    });

    it("Should change market owner", async () => {
        const encodedFunctionCall = market.interface.encodeFunctionData("transferOwnership", [
            iniOwnerAddress,
        ]);

        // Owner 1 approves new market owner
        const tx1 = await governance
            .connect(owner1)
            .proposeTransaction(market.address, 0, encodedFunctionCall);
        const receipt1 = await tx1.wait();
        const transactionIndex = receipt1.events[0].args.txIndex;
        let transaction = await governance.transactions(transactionIndex);
        const decodedFunctionCall = market.interface.decodeFunctionData(
            "transferOwnership",
            transaction.data
        );
        expect(transaction.to).to.equal(market.address);
        expect(Number(transaction.value)).to.equal(0);
        expect(decodedFunctionCall[0]).to.equal(iniOwnerAddress);
        assert(!transaction.executed);
        expect(Number(transaction.numConfirmations)).to.equal(1);

        // Owner1 tries to approve same market owner
        await throwsException(
            governance.connect(owner1).approveTransaction(transactionIndex),
            "Governance: Tx already approved"
        );

        // Owner2 tries to execute transfer ownership
        await throwsException(
            governance.connect(owner2).executeTransaction(transactionIndex),
            "Governance: Tx not approved"
        );

        // Owner 2 approves new market owner
        await governance.connect(owner2).approveTransaction(transactionIndex);

        // Owner3 executes transfer ownership
        await governance.connect(owner3).executeTransaction(transactionIndex);

        transaction = await governance.transactions(transactionIndex);
        assert(transaction.executed);
        expect(Number(transaction.numConfirmations)).to.equal(2);

        expect(await market.owner()).to.equal(iniOwnerAddress);

        // Owner3 executes transfer again
        await throwsException(
            governance.connect(owner2).executeTransaction(transactionIndex),
            "Governance: Tx already executed"
        );
    });
});
