# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xe124E8bD72Df842189e6E0762558191f267E5E9d](https://reefscan.com/contract/0xe124E8bD72Df842189e6E0762558191f267E5E9d)|[0x5728847Ca5d2466dE6AcD33597D874f480acdAdB](https://reefscan.com/contract/0x5728847Ca5d2466dE6AcD33597D874f480acdAdB)|[0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430](https://reefscan.com/contract/0x52CD9d5B4A9a3610Bd87668B5158B7d7259CA430)|
|**Testnet**|[0x6a52084Ac7cA7F6ebBbEb6145F4E12124B69f978](https://testnet.reefscan.com/contract/0x6a52084Ac7cA7F6ebBbEb6145F4E12124B69f978)|[0x4B36bA56C20e73d6803b218189a5cc20eaeB9bd5](https://testnet.reefscan.com/contract/0x4B36bA56C20e73d6803b218189a5cc20eaeB9bd5)|[0xDDD74ec6828937aaa00E31890fE289FFcBb78cfd](https://testnet.reefscan.com/contract/0xDDD74ec6828937aaa00E31890fE289FFcBb78cfd)|

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