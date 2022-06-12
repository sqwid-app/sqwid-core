require("@reef-defi/hardhat-reef");

const SEEDS = require("./seeds.json");

task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.4",
    defaultNetwork: "reef_testnet",
    networks: {
        reef: {
            url: "ws://127.0.0.1:9944",
            scanUrl: "http://localhost:8000",
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
            scanUrl: "https://testnet.reefscan.com",
            seeds: {
                account1: SEEDS.account1,
                account2: SEEDS.account2,
                account3: SEEDS.account3,
                account4: SEEDS.account4,
                account5: SEEDS.account5,
                account6: SEEDS.account6,
                account7: SEEDS.account7,
            },
        },
        reef_mainnet: {
            url: "wss://rpc.reefscan.com/ws",
            scanUrl: "https://reefscan.com",
            seeds: {
                mainnetAccount: SEEDS.mainnetAccount,
            },
        },
    },
    mocha: {
        timeout: 150000,
    },
    contracts: {
        market: "0x0a3F2785dBBC5F022De511AAB8846388B78009fD",
        nft: "0x1A511793FE92A62AF8bC41d65d8b94d4c2BD22c3",
        util: "0x08ABAa5BfeeB68D5cD3fb33Df49AA1F611CdE0cC",
        governance: "0x1a7C2eF2c3791018Dc89c54D98914bCd9c30CF35",
        balanceHelper: "0x6aC1413A64b153aA16fabbD9F97D30dC2CDE2604",
        gasBurner: "0xE6a505Fd9868AFd411EcB93d46EbB892Eb24E501",
        dummyERC721: "0xf5c05d8013724AC037eE6AD9CCea04905384bacE",
        dummyERC1155: "0x90232AC468647bFf589825680c78546E021c805B",
        dummyERC721Roy: "0x8E8369c30361A8Ad1C76922Dd4d8535582A40B8A",
    },
    optimizer: {
        enabled: true,
        runs: 200,
    },
};
