# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xe124E8bD72Df842189e6E0762558191f267E5E9d](https://reefscan.com/contract/0xe124E8bD72Df842189e6E0762558191f267E5E9d)|[0x5728847Ca5d2466dE6AcD33597D874f480acdAdB](https://reefscan.com/contract/0x5728847Ca5d2466dE6AcD33597D874f480acdAdB)|[0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430](https://reefscan.com/contract/0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430)|
|**Testnet**|[0xB2871bF369ce67cc0E251b449fc21A6DbAe93c2e](https://testnet.reefscan.com/contract/0xB2871bF369ce67cc0E251b449fc21A6DbAe93c2e)|[0x49aC7Dc3ddCAb2e08dCb8ED1F18a0E0369515E47](https://testnet.reefscan.com/contract/0x49aC7Dc3ddCAb2e08dCb8ED1F18a0E0369515E47)|[0x3b9097c5915DDbae1839D1A3E81DD52Df6bF2583](https://testnet.reefscan.com/contract/0x3b9097c5915DDbae1839D1A3E81DD52Df6bF2583)|

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

![diagram](sqwid-diagram-v02.png)