require("@reef-defi/hardhat-reef");

const SEEDS = require("./seeds.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.4",
    defaultNetwork: "reef_testnet",
    networks: {
        reef_local: {
            url: "ws://127.0.0.1:9944",
            seeds: {
                account1: SEEDS.account1,
                account2: SEEDS.account2,
                account3: SEEDS.account3,
                account4: SEEDS.account4,
                account5: SEEDS.account5,
                account6: SEEDS.account6,
            },
        },
        reef_testnet: {
            url: "wss://rpc-testnet.reefscan.com/ws",
            seeds: {
                account1: SEEDS.account1,
                account2: SEEDS.account2,
                account3: SEEDS.account3,
                account4: SEEDS.account4,
                account5: SEEDS.account5,
                account6: SEEDS.account6,
            },
        },
        reef_mainnet: {
            url: "wss://rpc.reefscan.com/ws",
            seeds: {
                mainnetAccount: SEEDS.mainnetAccount,
            },
        },
    },
    mocha: {
        timeout: 150000,
    },
    contracts: {
        market: "0x40088b7c8b3f4c07df401Ee7ad2e0e0725152aB6",
        nft: "0x0Db640C90Edd6B84087EF58Ecc175e5c8b47687a",
        reef: "0x0000000000000000000000000000000001000000",
    },
};
