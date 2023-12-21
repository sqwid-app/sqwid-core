# Sqwid Marketplace Core

This project has been created using the [Hardhat-reef-template](https://github.com/reef-defi/hardhat-reef-template).

## Contract addresses

| |Marketplace contract|NFT contract|Util contract|
|-----|-----|-----|-----|
|**Mainnet**|[0xB13Be9656B243600C86922708C20606f5EA89218](https://reefscan.com/contract/0xB13Be9656B243600C86922708C20606f5EA89218)|[0x0601202b75C96A61CDb9A99D4e2285E43c6e60e4](https://reefscan.com/contract/0x0601202b75C96A61CDb9A99D4e2285E43c6e60e4)|[0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733](https://reefscan.com/contract/0xffb12A5f69AFBD58Dc49b4AE9044D8F20D131733)|
|**Testnet**|[0x31939DF5c6A5ac0b574EDE6E610Fd30c08788A53](https://testnet.reefscan.com/contract/0x31939DF5c6A5ac0b574EDE6E610Fd30c08788A53)|[0x9FdEb478A27E216f80DaEE0967dc426338eD02f2](https://testnet.reefscan.com/contract/0x9FdEb478A27E216f80DaEE0967dc426338eD02f2)|[0x8E7Ef6bD28cD9bDb6DBf105140958ac03EeC371A](https://testnet.reefscan.com/contract/0x8E7Ef6bD28cD9bDb6DBf105140958ac03EeC371A)|

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
