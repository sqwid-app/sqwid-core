# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xB13Be9656B243600C86922708C20606f5EA89218](https://reefscan.com/contract/0xB13Be9656B243600C86922708C20606f5EA89218)|[0x0601202b75C96A61CDb9A99D4e2285E43c6e60e4](https://reefscan.com/contract/0x0601202b75C96A61CDb9A99D4e2285E43c6e60e4)|[0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733](https://reefscan.com/contract/0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733)|
|**Testnet**|[0xB4630116Dca95650C1E56F3dD39c7edeb1075B38](https://testnet.reefscan.com/contract/0xB4630116Dca95650C1E56F3dD39c7edeb1075B38)|[0xc2F3BE4636A0a1ddf3b4D63ef22014DD41114336](https://testnet.reefscan.com/contract/0xc2F3BE4636A0a1ddf3b4D63ef22014DD41114336)|[0x30eDebE433702029C00544615aCC4E1b445939BA](https://testnet.reefscan.com/contract/0x30eDebE433702029C00544615aCC4E1b445939BA)|

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

In order to use your Reef account to deploy the contracts or run the tests, you have to rename the _seeds.example.json_ file to _seeds.json_ and set your seed words there.

## Diagram

![diagram](sqwid-diagram-v02.png)

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
