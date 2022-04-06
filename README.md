# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xe3f2740452A860c6441456aDF86D6d0be715ae82](https://reefscan.com/contract/0xe3f2740452A860c6441456aDF86D6d0be715ae82)|[0xa1957161Ee6Cb6D86Ae7A9cE12A30C40Dc9F1B68](https://reefscan.com/contract/0xa1957161Ee6Cb6D86Ae7A9cE12A30C40Dc9F1B68)|[0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733](https://reefscan.com/contract/0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733)|
|**Testnet**|[0xd3202Ee6077C7cc25eAea3aE11bec2cD731D19FC](https://testnet.reefscan.com/contract/0xd3202Ee6077C7cc25eAea3aE11bec2cD731D19FC)|[0x49aC7Dc3ddCAb2e08dCb8ED1F18a0E0369515E47](https://testnet.reefscan.com/contract/0x49aC7Dc3ddCAb2e08dCb8ED1F18a0E0369515E47)|[0x08925246669D150d5D4597D756A3C788eae2834B](https://testnet.reefscan.com/contract/0x08925246669D150d5D4597D756A3C788eae2834B)|

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