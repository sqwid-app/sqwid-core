# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xe3f2740452A860c6441456aDF86D6d0be715ae82](https://reefscan.com/contract/0xe3f2740452A860c6441456aDF86D6d0be715ae82)|[0xa1957161Ee6Cb6D86Ae7A9cE12A30C40Dc9F1B68](https://reefscan.com/contract/0xa1957161Ee6Cb6D86Ae7A9cE12A30C40Dc9F1B68)|[0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733](https://reefscan.com/contract/0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733)|
|**Testnet**|[0x0a3F2785dBBC5F022De511AAB8846388B78009fD](https://testnet.reefscan.com/contract/0x0a3F2785dBBC5F022De511AAB8846388B78009fD)|[0x1A511793FE92A62AF8bC41d65d8b94d4c2BD22c3](https://testnet.reefscan.com/contract/0x1A511793FE92A62AF8bC41d65d8b94d4c2BD22c3)|[0x08925246669D150d5D4597D756A3C788eae2834B](https://testnet.reefscan.com/contract/0x08925246669D150d5D4597D756A3C788eae2834B)|

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