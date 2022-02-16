const { expect } = require("chai");
const {
    getMainContracts,
    getBalanceHelper,
    getBalance,
    throwsException,
    delay,
} = require("./util");

describe("************ Loans ******************", () => {
    let token1Id, token2Id, loan1Id, loan2Id, loan3Id, item1Id;

    before(async () => {
        // Get accounts
        owner = await reef.getSignerByName("account1");
        borrower = await reef.getSignerByName("account2");
        lender = await reef.getSignerByName("account3");
        const artist = await reef.getSignerByName("account4");

        // Get accounts addresses
        ownerAddress = await owner.getAddress();
        borrowerAddress = await borrower.getAddress();
        lenderAddress = await lender.getAddress();
        artistAddress = await artist.getAddress();

        // Initialize global variables
        maxGasFee = ethers.utils.parseUnits("10", "ether");
        loanAmount = ethers.utils.parseUnits("200", "ether");
        feeAmount = ethers.utils.parseUnits("20", "ether");
        loanDuration = 1; // Min loan duration is 1440 min. Change in contract to 1 min for testing.
        royaltyValue = 1000; // 10%
        token1Amount = 1000;
        token2Amount = 1;
        marketFee = 250; // 2.5%

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, owner);
        nft = contracts.nft;
        market = contracts.market;
        marketUtil = contracts.marketUtil;
        balanceHelper = await getBalanceHelper();
    });

    it("Should create loan proposal", async () => {
        // Approve market contract
        console.log("\tcreating approval for market contract...");
        await nft.connect(borrower).setApprovalForAll(market.address, true);
        console.log("\tapproval created");

        // Initial data
        const iniLoans = await marketUtil.fetchPositionsByState(4);

        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(borrower)
            .mint(token1Amount, "https://fake-uri.com", "image", artistAddress, royaltyValue);
        const receipt1 = await tx1.wait();
        item1Id = receipt1.events[2].args[0].toNumber();
        token1Id = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${token1Id}`);
        console.log(`\tMarket item created with itemId ${item1Id}`);

        // Create loan proposal
        console.log("\tborrower creating loan proposal...");
        const tx2 = await market
            .connect(borrower)
            .createItemLoan(item1Id, loanAmount, feeAmount, token1Amount, loanDuration);
        const receipt2 = await tx2.wait();
        loan1Id = receipt2.events[1].args[0].toNumber();
        console.log(`\tLoan proposal created with id ${loan1Id}`);

        // Final data
        const endLoans = await marketUtil.fetchPositionsByState(4);
        const loan = await marketUtil.fetchPosition(loan1Id);
        const endBorrowerTokenAmount = await nft.balanceOf(borrowerAddress, token1Id);
        const endMarketTokenAmount = await nft.balanceOf(market.address, token1Id);

        // Evaluate results
        expect(Number(loan.item.itemId)).to.equal(item1Id);
        expect(Number(endBorrowerTokenAmount)).to.equal(0);
        expect(Number(endMarketTokenAmount)).to.equal(token1Amount);
        expect(endLoans.length).to.equal(iniLoans.length + 1);
        expect(loan.item.nftContract).to.equal(nft.address);
        expect(Number(loan.item.tokenId)).to.equal(token1Id);
        expect(loan.owner).to.equal(borrowerAddress);
        expect(loan.item.creator).to.equal(borrowerAddress);
        expect(loan.state).to.equal(4); // Loan = 4
        expect(Number(loan.loanData.loanAmount)).to.equal(Number(loanAmount));
        expect(Number(loan.loanData.feeAmount)).to.equal(Number(feeAmount));
        expect(Number(loan.loanData.numMinutes)).to.equal(loanDuration);
        expect(parseInt(loan.loanData.lender, 16)).to.equal(0);
        expect(Number(loan.loanData.deadline)).to.equal(0);
    });

    it("Should only allow to unlist loan to borrower", async () => {
        // Initial data
        const iniLoans = await marketUtil.fetchPositionsByState(4);
        const iniBorrowerTokenAmount = await nft.balanceOf(borrowerAddress, token1Id);
        const iniMarketTokenAmount = await nft.balanceOf(market.address, token1Id);

        console.log(`\tlender unlisting loan proposal ${loan1Id}...`);
        await throwsException(
            market.connect(lender).unlistLoanProposal(loan1Id),
            "SqwidMarket: Only borrower can unlist"
        );

        console.log("\tborrower unlisting loan proposal...");
        await market.connect(borrower).unlistLoanProposal(loan1Id);
        console.log("\tLoan proposal unlisted.");

        // Final data
        const endLoans = await marketUtil.fetchPositionsByState(4);
        const endBorrowerTokenAmount = await nft.balanceOf(borrowerAddress, token1Id);
        const endMarketTokenAmount = await nft.balanceOf(market.address, token1Id);

        expect(endBorrowerTokenAmount - iniBorrowerTokenAmount).to.equal(token1Amount);
        expect(iniMarketTokenAmount - endMarketTokenAmount).to.equal(token1Amount);
        expect(endLoans.length).to.equal(iniLoans.length - 1);
    });

    it("Should fund loan", async () => {
        // Create new loan proposal
        console.log("\tborrower creating loan proposal...");
        const tx = await market
            .connect(borrower)
            .createItemLoan(item1Id, loanAmount, feeAmount, token1Amount, loanDuration);
        const receipt = await tx.wait();
        loan2Id = receipt.events[1].args[0];
        console.log(`\tloan proposal created with id ${loan2Id}`);

        // Initial data
        const iniLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const iniBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");
        const iniMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const iniOwnerMarketBalance = await market.addressBalance(ownerAddress);

        // Fund proposal
        console.log("\tlender funding loan...");
        await market.connect(lender).fundLoan(loan2Id, { value: loanAmount });
        console.log("\tloan proposal created");

        // Final data
        const loan = await marketUtil.fetchPosition(loan2Id);
        const endLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const endBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");
        const endMarketBalance = await getBalance(balanceHelper, market.address, "market");
        const endOwnerMarketBalance = await market.addressBalance(ownerAddress);
        deadline = new Date(loan.loanData.deadline * 1000);
        const marketFeeAmountRaw = (loanAmount * marketFee) / 10000;
        const marketFeeAmount = ethers.utils.parseUnits(marketFeeAmountRaw.toString(), "wei");

        // Evaluate results
        expect(loan.loanData.lender).to.equal(lenderAddress);
        expect(Number(endBorrowerBalance)).to.equals(
            Number(iniBorrowerBalance.add(loanAmount).sub(marketFeeAmount))
        );
        expect(Number(endLenderBalance))
            .to.lte(Number(iniLenderBalance.sub(loanAmount)))
            .gt(Number(iniLenderBalance.sub(loanAmount).sub(maxGasFee)));
        expect(Number(endMarketBalance)).to.equal(Number(iniMarketBalance.add(marketFeeAmount)));
        expect(Number(endOwnerMarketBalance)).to.equal(
            Number(iniOwnerMarketBalance.add(marketFeeAmount))
        );
        expect(deadline)
            .to.lt(new Date(new Date().getTime() + 90000))
            .to.gt(new Date(new Date().getTime() + 30000)); // +/- 30 secs. margin for timestamp calculation
    });

    it("Should not allow to unlist funded loan", async () => {
        await throwsException(
            market.connect(borrower).unlistLoanProposal(loan2Id),
            "SqwidMarket: Loan already funded"
        );
    });

    it("Should not liquidate loan before deadline", async () => {
        console.log("\tliquidating loan...");
        await throwsException(
            market.connect(lender).liquidateLoan(loan2Id),
            "SqwidMarket: Deadline not reached"
        );
    });

    it("Should liquidate loan", async () => {
        // Initial data
        const iniLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const iniBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");
        const iniLoans = await marketUtil.fetchPositionsByState(4);
        const iniLenderTokenAmount = await nft.balanceOf(lenderAddress, token1Id);
        const iniMarketTokenAmount = await nft.balanceOf(market.address, token1Id);
        const iniLenderPositions = await marketUtil.fetchAddressPositions(lenderAddress);

        // Wait until deadline
        const timeUntilDeadline = deadline - new Date();
        console.log(`\ttime until deadline: ${timeUntilDeadline / 1000} secs.`);
        if (timeUntilDeadline > 0) {
            console.log("\twaiting for deadline...");
            await delay(timeUntilDeadline + 15000);
            console.log("\tdeadline reached.");
        }

        // Liquidate loan
        console.log("\tliquidating loan...");
        await market.connect(lender).liquidateLoan(loan2Id);
        console.log("\tloan liquidated...");

        // Final data
        const endLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const endBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");
        const endLoans = await marketUtil.fetchPositionsByState(4);
        const endLenderTokenAmount = await nft.balanceOf(lenderAddress, token1Id);
        const endMarketTokenAmount = await nft.balanceOf(market.address, token1Id);
        const endLenderPositions = await marketUtil.fetchAddressPositions(lenderAddress);

        // Evaluate results
        expect(endLenderTokenAmount - iniLenderTokenAmount).to.equal(token1Amount);
        expect(
            iniLenderPositions.indexOf(
                (pos) => Number(pos.item.itemId) == item1Id && pos.state == 0
            )
        ).to.equal(-1);
        expect(
            Number(
                endLenderPositions.find(
                    (pos) => Number(pos.item.itemId) == item1Id && pos.state == 0
                ).amount
            )
        ).to.equal(token1Amount);
        expect(iniMarketTokenAmount - endMarketTokenAmount).to.equal(token1Amount);
        expect(endLoans.length).to.equal(iniLoans.length - 1);
        expect(Number(endBorrowerBalance)).to.equals(Number(iniBorrowerBalance));
        expect(Number(endLenderBalance))
            .to.lte(Number(iniLenderBalance))
            .gt(Number(iniLenderBalance.sub(maxGasFee)));
    });

    it("Should not repay loan if value sent is not enough", async () => {
        // Create token and add to the market
        console.log("\tcreating market item...");
        const tx1 = await market
            .connect(borrower)
            .mint(token2Amount, "https://fake-uri.com", "image", artistAddress, royaltyValue);
        const receipt1 = await tx1.wait();
        item2Id = receipt1.events[2].args[0].toNumber();
        token2Id = receipt1.events[2].args[2].toNumber();
        console.log(`\tNFT created with tokenId ${token2Id}`);
        console.log(`\tMarket item created with itemId ${item2Id}`);

        // Create loan proposal
        console.log("\tborrower creating loan proposal...");
        await market
            .connect(borrower)
            .createItemLoan(item2Id, loanAmount, feeAmount, token2Amount, loanDuration);
        console.log("\tloan proposal created");

        const loan = (await marketUtil.fetchPositionsByState(4)).at(-1);
        loan3Id = loan.positionId;

        // Fund proposal
        console.log("\tlender funding loan...");
        await market.connect(lender).fundLoan(loan3Id, { value: loanAmount });
        console.log("\tloan funded.");

        // Repay loan
        console.log("\tborrower repaying loan...");
        await throwsException(
            market.connect(borrower).repayLoan(loan3Id, { value: loanAmount }),
            "SqwidMarket: Value sent invalid"
        );
    });

    it("Should repay loan", async () => {
        // Initial data
        const iniBorrowerTokenAmount = await nft.balanceOf(borrowerAddress, token2Id);
        const iniMarketTokenAmount = await nft.balanceOf(market.address, token2Id);
        const iniLoans = await marketUtil.fetchPositionsByState(4);
        const iniLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const iniBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");

        // Repay loan
        console.log("\tborrower repaying loan...");
        await market.connect(borrower).repayLoan(loan3Id, { value: loanAmount.add(feeAmount) });
        console.log("\tloan repayed.");

        // Final data
        const endBorrowerTokenAmount = await nft.balanceOf(borrowerAddress, token2Id);
        const endMarketTokenAmount = await nft.balanceOf(market.address, token2Id);
        const endLoans = await marketUtil.fetchPositionsByState(4);
        const endLenderBalance = await getBalance(balanceHelper, lenderAddress, "lender");
        const endBorrowerBalance = await getBalance(balanceHelper, borrowerAddress, "borrower");

        // Evaluate results
        expect(Number(endLenderBalance)).to.equals(
            Number(iniLenderBalance.add(loanAmount).add(feeAmount))
        );
        expect(Number(endBorrowerBalance))
            .to.lte(Number(iniBorrowerBalance.sub(loanAmount).sub(feeAmount)))
            .gt(Number(iniBorrowerBalance.sub(loanAmount).sub(feeAmount).sub(maxGasFee)));
        expect(endBorrowerTokenAmount - iniBorrowerTokenAmount).to.equal(token2Amount);
        expect(iniMarketTokenAmount - endMarketTokenAmount).to.equal(token2Amount);
        expect(endLoans.length).to.equal(iniLoans.length - 1);
    });
});
