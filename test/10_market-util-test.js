const { getMainContracts, throwsException } = require("./util");

describe.only("************ Market Util ******************", () => {
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

        console.log("\nItems from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const items = [];
            const res = await marketUtil.fetchItems(pageSize, i, false);
            res.items.forEach((item) => {
                items.push(Number(item.itemId));
            });
            console.log(`  Page ${i}:`, items);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchItems(pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nItems from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const itemsReverse = [];
            const res = await marketUtil.fetchItems(pageSize, i, true);
            res.items.forEach((item) => {
                itemsReverse.push(Number(item.itemId));
            });
            console.log(`  Page ${i}:`, itemsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchItems(pageSize, totalPages + 1, true),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get created items", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numItems = await marketUtil.fetchAddressNumberItemsCreated(addr);
            console.log(`\nAddress ${index + 1} created items: ${numItems}`);
            console.log("========================");
            const totalPages = Math.ceil(numItems / pageSize);

            console.log("\nCreated items from newest to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const items = [];
                const res = await marketUtil.fetchAddressItemsCreated(addr, pageSize, i, false);
                res.items.forEach((item) => {
                    items.push(Number(item.itemId));
                });
                console.log(`  Page ${i}:`, items);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressItemsCreated(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }

            console.log("\nCreated items from newst to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const itemsReverse = [];
                const res = await marketUtil.fetchAddressItemsCreated(addr, pageSize, i, true);
                res.items.forEach((item) => {
                    itemsReverse.push(Number(item.itemId));
                });
                console.log(`  Page ${i}:`, itemsReverse);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressItemsCreated(addr, pageSize, totalPages + 1, true),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get address positions", async () => {
        for (let index = 0; index < accountAddresses.length; index++) {
            const addr = accountAddresses[index];
            const numPositions = await marketUtil.fetchAddressNumberPositions(addr);
            console.log(`\nAddress ${index + 1} positions: ${numPositions}`);
            console.log("====================");
            const totalPages = Math.ceil(numPositions / pageSize);

            console.log("\nPositions from newest to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const positions = [];
                const res = await marketUtil.fetchAddressPositions(addr, pageSize, i, false);
                res.positions.forEach((pos) => {
                    positions.push(Number(pos.positionId));
                });
                console.log(`  Page ${i}:`, positions);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressPositions(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }

            console.log("\nPositions from newst to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const positionsReverse = [];
                const res = await marketUtil.fetchAddressPositions(addr, pageSize, i, true);
                res.positions.forEach((pos) => {
                    positionsReverse.push(Number(pos.positionId));
                });
                console.log(`  Page ${i}:`, positionsReverse);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressPositions(addr, pageSize, totalPages + 1, true),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });

    it("Should get available positions", async () => {
        const numPositions = await marketUtil.fetchNumberPositionsByState(0);
        console.log(`\nAvailable positions: ${numPositions}`);
        console.log("====================");
        const totalPages = Math.ceil(numPositions / pageSize);

        console.log("\nItems from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByState(0, pageSize, i, false);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(0, pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nItems from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const positionsReverse = [];
            const res = await marketUtil.fetchPositionsByState(0, pageSize, i, true);
            res.positions.forEach((pos) => {
                positionsReverse.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positionsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(0, pageSize, totalPages + 1, true),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on sale", async () => {
        const numPositions = await marketUtil.fetchNumberPositionsByState(1);
        console.log(`\nPositions on sale: ${numPositions}`);
        console.log("==================");
        const totalPages = Math.ceil(numPositions / pageSize);

        console.log("\nOn sale from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByState(1, pageSize, i, false);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(1, pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nOn sale from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const positionsReverse = [];
            const res = await marketUtil.fetchPositionsByState(1, pageSize, i, true);
            res.positions.forEach((pos) => {
                positionsReverse.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positionsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(1, pageSize, totalPages + 1, true),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on auction", async () => {
        const numPositions = await marketUtil.fetchNumberPositionsByState(2);
        console.log(`\nAuctions: ${numPositions}`);
        console.log("=========");
        const totalPages = Math.ceil(numPositions / pageSize);

        console.log("\nAuctions from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByState(2, pageSize, i, false);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(2, pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nAuctions from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const positionsReverse = [];
            const res = await marketUtil.fetchPositionsByState(2, pageSize, i, true);
            res.positions.forEach((pos) => {
                positionsReverse.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positionsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(2, pageSize, totalPages + 1, true),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on raffle", async () => {
        const numPositions = await marketUtil.fetchNumberPositionsByState(3);
        console.log(`\nRaffle positions: ${numPositions}`);
        console.log("=================");
        const totalPages = Math.ceil(numPositions / pageSize);

        console.log("\nRaffles from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByState(3, pageSize, i, false);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(3, pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nRaffles from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const positionsReverse = [];
            const res = await marketUtil.fetchPositionsByState(3, pageSize, i, true);
            res.positions.forEach((pos) => {
                positionsReverse.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positionsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(3, pageSize, totalPages + 1, true),
                "SqwidMarketUtil: Invalid page number"
            );
        }
    });

    it("Should get positions on loan", async () => {
        const numPositions = await marketUtil.fetchNumberPositionsByState(4);
        console.log(`\nLoan positions: ${numPositions}`);
        console.log("==============");
        const totalPages = Math.ceil(numPositions / pageSize);

        console.log("\nLoans from oldest to newest:");
        for (let i = 1; i <= totalPages; i++) {
            const positions = [];
            const res = await marketUtil.fetchPositionsByState(4, pageSize, i, false);
            res.positions.forEach((pos) => {
                positions.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positions);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(4, pageSize, totalPages + 1, false),
                "SqwidMarketUtil: Invalid page number"
            );
        }

        console.log("\nLoans from newest to oldest:");
        for (let i = 1; i <= totalPages; i++) {
            const positionsReverse = [];
            const res = await marketUtil.fetchPositionsByState(4, pageSize, i, true);
            res.positions.forEach((pos) => {
                positionsReverse.push(Number(pos.positionId));
            });
            console.log(`  Page ${i}:`, positionsReverse);
        }
        if (totalPages) {
            await throwsException(
                marketUtil.fetchPositionsByState(4, pageSize, totalPages + 1, true),
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

            console.log("\nBids from oldest to newest:");
            for (let i = 1; i <= totalPages; i++) {
                const bids = [];
                const res = await marketUtil.fetchAddressBids(addr, pageSize, i, false);
                res.bids.forEach((bid) => {
                    bids.push(Number(bid.auction.positionId));
                });
                console.log(`  Page ${i}:`, bids);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressBids(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }

            console.log("\nBids from newest to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const bidsReverse = [];
                const res = await marketUtil.fetchAddressBids(addr, pageSize, i, true);
                res.bids.forEach((bid) => {
                    bidsReverse.push(Number(bid.auction.positionId));
                });
                console.log(`  Page ${i}:`, bidsReverse);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressBids(addr, pageSize, totalPages + 1, true),
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

            console.log("\nRaffles from oldest to newest:");
            for (let i = 1; i <= totalPages; i++) {
                const raffles = [];
                const res = await marketUtil.fetchAddressRaffles(addr, pageSize, i, false);
                res.raffles.forEach((raffle) => {
                    raffles.push(Number(raffle.raffle.positionId));
                });
                console.log(`  Page ${i}:`, raffles);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressRaffles(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }

            console.log("\nRaffles from newest to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const rafflesReverse = [];
                const res = await marketUtil.fetchAddressRaffles(addr, pageSize, i, true);
                res.raffles.forEach((raffle) => {
                    rafflesReverse.push(Number(raffle.raffle.positionId));
                });
                console.log(`  Page ${i}:`, rafflesReverse);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressRaffles(addr, pageSize, totalPages + 1, true),
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

            console.log("\nLoans from oldest to newest:");
            for (let i = 1; i <= totalPages; i++) {
                const loans = [];
                const res = await marketUtil.fetchAddressLoans(addr, pageSize, i, false);
                res.loans.forEach((loan) => {
                    loans.push(Number(loan.positionId));
                });
                console.log(`  Page ${i}:`, loans);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressLoans(addr, pageSize, totalPages + 1, false),
                    "SqwidMarketUtil: Invalid page number"
                );
            }

            console.log("\nLoans from newest to oldest:");
            for (let i = 1; i <= totalPages; i++) {
                const loansReverse = [];
                const res = await marketUtil.fetchAddressLoans(addr, pageSize, i, true);
                res.loans.forEach((loan) => {
                    loansReverse.push(Number(loan.positionId));
                });
                console.log(`  Page ${i}:`, loansReverse);
            }
            if (totalPages) {
                await throwsException(
                    marketUtil.fetchAddressLoans(addr, pageSize, totalPages + 1, true),
                    "SqwidMarketUtil: Invalid page number"
                );
            }
        }
    });
});
