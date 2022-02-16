# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xe124E8bD72Df842189e6E0762558191f267E5E9d](https://reefscan.com/contract/0xe124E8bD72Df842189e6E0762558191f267E5E9d)|[0x5728847Ca5d2466dE6AcD33597D874f480acdAdB](https://reefscan.com/contract/0x5728847Ca5d2466dE6AcD33597D874f480acdAdB)|[0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430](https://reefscan.com/contract/0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430)|
|**Testnet**|[0xEde8b3844E01444a9D3E0aCDd118f97827f179A4](https://testnet.reefscan.com/contract/0xEde8b3844E01444a9D3E0aCDd118f97827f179A4)|[0x03aE38D60a5F97a747980d6EC4B1CdDAAb9F1979](https://testnet.reefscan.com/contract/0x03aE38D60a5F97a747980d6EC4B1CdDAAb9F1979)|[0x7E2f35C171Ea6B96B45acBC079D391e06097a5E0](https://testnet.reefscan.com/contract/0x7E2f35C171Ea6B96B45acBC079D391e06097a5E0)|

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
