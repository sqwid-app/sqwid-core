const { getMainContracts, throwsException } = require("./util");

describe("************ Market Util ******************", () => {
    before(async () => {
        // Get accounts
        account2 = await reef.getSignerByName("account2");
        account3 = await reef.getSignerByName("account3");
        account4 = await reef.getSignerByName("account4");
        accounts = [account2, account3, account4];

        // Get accounts addresses
        account2Address = await account2.getAddress();
        account3Address = await account3.getAddress();
        account4Address = await account4.getAddress();
        accountAddresses = [account2Address, account3Address, account4Address];

        // Initialize global variables
        marketFee = 250; // 2.5%
        royaltyValue = 1000; // 10%
        pageSize = 10;

        // Deploy or get existing contracts
        const contracts = await getMainContracts(marketFee, await reef.getSignerByName("account1"));
        market = contracts.market;
        marketUtil = contracts.marketUtil;
    });

    it("Should get all items", async () => {
        const numItems = await marketUtil.fetchNumberItems();
        console.log(`\nTotal number of items: ${numItems}`);
        console.log("======================");
        const totalPages = Math.ceil(numItems / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const items = [];
            const res = await marketUtil.fetchItemsPage(pageSize, i);
            res.items.forEach((item) => {
                items.push(Number(item.itemId));
            });
            console.log(`  Page ${i}:`, items);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchItemsPage(pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get address positions", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numPositions = await marketUtil.fetchAddressNumberPositions(addr);
            console.log(`\nAddress ${index + 1} positions: ${numPositions}`);
            console.log("====================");
            const totalPages = Math.ceil(numPositions / pageSize);

            for (let i = 1; i <= totalPages; i++) {
                const positions = [];
                const res = await marketUtil.fetchAddressPositionsPage(addr, pageSize, i);
                res.positions.forEach((pos) => {
                    positions.push(Number(pos.positionId));
                });
                console.log(`  Page ${i}:`, positions);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressPositionsPage(addr, pageSize, totalPages + 1),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get available positions", async () => {
        const numPositions = await market.fetchStateCount(0);
        console.log(`\nAvailable positions: ${numPositions}`);
        console.log("====================");
        const totalPages = Math.ceil(numPositions / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByStatePage(0, pageSize, i);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByStatePage(0, pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on sale", async () => {
        const numPositions = await market.fetchStateCount(1);
        console.log(`\nPositions on sale: ${numPositions}`);
        console.log("==================");
        const totalPages = Math.ceil(numPositions / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByStatePage(1, pageSize, i);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByStatePage(1, pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on auction", async () => {
        const numPositions = await market.fetchStateCount(2);
        console.log(`\nAuctions: ${numPositions}`);
        console.log("=========");
        const totalPages = Math.ceil(numPositions / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByStatePage(2, pageSize, i);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByStatePage(2, pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on raffle", async () => {
        const numPositions = await market.fetchStateCount(3);
        console.log(`\nRaffle positions: ${numPositions}`);
        console.log("=================");
        const totalPages = Math.ceil(numPositions / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByStatePage(3, pageSize, i);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByStatePage(3, pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on loan", async () => {
        const numPositions = await market.fetchStateCount(4);
        console.log(`\nLoan positions: ${numPositions}`);
        console.log("==============");
        const totalPages = Math.ceil(numPositions / pageSize);

        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByStatePage(4, pageSize, i);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByStatePage(4, pageSize, totalPages + 1),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get address bids", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numBids = await marketUtil.fetchAddressNumberBids(addr);
            console.log(`\nAddress ${index + 1} bids: ${numBids}`);
            console.log("===============");
            const totalPages = Math.ceil(numBids / pageSize);

            for (let i = 1; i <= totalPages; i++) {
                const bids = [];
                const res = await marketUtil.fetchAddressBidsPage(addr, pageSize, i, false);
                res.bids.forEach((bid) => {
                    bids.push(Number(bid.auction.positionId));
                });
                console.log(`  Page ${i}:`, bids);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressBidsPage(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get address entered raffles", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numRaffles = await marketUtil.fetchAddressNumberRaffles(addr);
            console.log(`\nAddress ${index + 1} raffles: ${numRaffles}`);
            console.log("==================");
            const totalPages = Math.ceil(numRaffles / pageSize);

            for (let i = 1; i <= totalPages; i++) {
                const raffles = [];
                const res = await marketUtil.fetchAddressRafflesPage(addr, pageSize, i, false);
                res.raffles.forEach((raffle) => {
                    raffles.push(Number(raffle.raffle.positionId));
                });
                console.log(`  Page ${i}:`, raffles);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressRafflesPage(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get address funded loans", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numLoans = await marketUtil.fetchAddressNumberLoans(addr);
            console.log(`\nAddress ${index + 1} loans: ${numLoans}`);
            console.log("=================");
            const totalPages = Math.ceil(numLoans / pageSize);

            for (let i = 1; i <= totalPages; i++) {
                const loans = [];
                const res = await marketUtil.fetchAddressLoansPage(addr, pageSize, i, false);
                res.loans.forEach((loan) => {
                    loans.push(Number(loan.positionId));
                });
                console.log(`  Page ${i}:`, loans);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressLoansPage(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get verified items", async () => {
        console.log("\nItems by ids:");
        console.log("==============");

        const numItems = await marketUtil.fetchNumberItems();
        console.log(`total items: ${Number(numItems)}`);

        const approvedIds = [];
        for (let i = 3; i <= numItems; i += 3) {
            approvedIds.push(i);
        }
        let approvedIdsPacked = getBoolsArray(approvedIds);

        const res = await marketUtil.fetchItems(0, 100, approvedIdsPacked);
        res.forEach((item) => {
            console.log(`itemId ${Number(item.itemId)}`);
        });
    });

    it("Should get positions from verified positions", async () => {
        console.log("\nVerified positions:");
        console.log("===============");

        const numItems = await marketUtil.fetchNumberItems();
        console.log(`total items: ${Number(numItems)}`);

        const numPositions = await market.currentPositionId();
        console.log(`total positions: ${Number(numPositions)}`);

        const approvedIds = [];
        for (let i = 1; i <= numItems; i += 1) {
            approvedIds.push(i);
        }
        let approvedIdsPacked = getBoolsArray(approvedIds);

        const res = await marketUtil.fetchPositions(
            0,
            ethers.constants.AddressZero,
            0,
            100,
            approvedIdsPacked
        );
        res.forEach((position) => {
            console.log(
                `positionId: ${Number(position.positionId)} - itemId ${Number(
                    position.item.itemId
                )}`
            );
        });
    });
});

const setBoolean = (packedBools, boolNumber, value) => {
    if (value) return packedBools | (1 << boolNumber);
    else return packedBools & (~1 << boolNumber);
};

const sliceIntoChunks = (arr, chunkSize) => {
    const res = [];
    for (let i = 0; i < arr.length; i += chunkSize) {
        const chunk = arr.slice(i, i + chunkSize);
        res.push(chunk);
    }
    return res;
};

const maxOfArray = (arr) => {
    return arr.reduce(function (a, b) {
        return Math.max(a, b);
    }, -Infinity);
};

const getBoolsArray = (arr) => {
    const max = maxOfArray(arr);
    let filledArray = new Array(max + 1).fill(false).map((_, i) => arr.includes(i));
    let chunks = sliceIntoChunks(filledArray, 8);
    let packed = [];
    chunks.forEach((chunk, index) => {
        let num = 0;
        while (chunk.length) {
            num = setBoolean(num, chunk.length - 1, chunk[chunk.length - 1]);
            chunk.pop();
        }
        packed[index] = num;
    });

    return packed;
};
