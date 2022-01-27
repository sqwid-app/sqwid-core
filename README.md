# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

|             | Marketplace contract                             | NFT contract                                     |
| ----------- | ------------------------------------------------ | ------------------------------------------------ |
| **Mainnet** | [0x0](https://reefscan.com/contract/0x0)         | [0x0](https://reefscan.com/contract/0x0)         |
| **Testnet** | [0x0](https://testnet.reefscan.com/contract/0x0) | [0x0](https://testnet.reefscan.com/contract/0x0) |

## Installing

Install all dependencies with `yarn`.

## Compile contracts

```bash
yarn compile
```

## Deploy contracts

Deploy in testnet:

```bash
yarn deploy
```

Deploy in mainnet:

```bash
yarn deploy:mainnet
```

## Run tests

```bash
yarn test
```

To reuse a contract already deployed, set its address in the _hardhat.config.js_ file, in the _contracts_ section. If no address is specified, a new contract will be deployed.

## Use account seeds

In order to use your Reef account to deploy the contracts or run the tests, you have to rename the _seeds.example.json_ file to _seeds.json_ and write your set your seed words there.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
