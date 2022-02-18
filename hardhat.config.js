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
        market: "0x4eacc63FC1b76b453aF8e3871d4F320b2e461408",
        nft: "0x03aE38D60a5F97a747980d6EC4B1CdDAAb9F1979",
        util: "0x7E2f35C171Ea6B96B45acBC079D391e06097a5E0",
        governance: "0xdEDa2F0eDde18bca36639B2896Ce66CbCc3C45f9",
        balanceHelper: "0x6aC1413A64b153aA16fabbD9F97D30dC2CDE2604",
        dummyERC721: "0xf5c05d8013724AC037eE6AD9CCea04905384bacE",
        dummyERC1155: "0x90232AC468647bFf589825680c78546E021c805B",
        dummyERC721Roy: "0x8E8369c30361A8Ad1C76922Dd4d8535582A40B8A",
    },
    optimizer: {
        enabled: true,
        runs: 200,
    },
};
