# KipuBank

This repository contains a simple contract as a proposed solution for the KipuBank module activity from the Blockchain course provided by [ETH Kipu](https://www.ethkipu.org).

## Requirements

In order to develop for this repository you will need the following:

- [Node.js v22.18 or higher](https://nodejs.org)

You will also need an account in [MetaMask](https://metamask.io), [Alchemy](https://www.alchemy.com), and [Etherscan](https://etherscan.io).

## Setting Up

First, clone this repository:

```bash
git clone https://github.com/moonstar-x/eth-kipu-bank
```

And install the dependencies:

```bash
npm install
```

## Testing

To run unit tests for this project, run the following command:

```bash
npm run test
```

You may also run tests in Solidity only with:

```bash
npm run test:solidity
```

Or only in Node.js with:

```bash
npm run test:ts
```

## Linting

To run the linter, use:

```bash
npm run lint
```

And to auto-fix issues, use:

```bash
npm run lint:fix
```

## Deploying

Follow these steps to deploy and verify this contract.

First, copy the `.env.sample` file into a `.env` file and fill out the values as necessary.

Both `KIPU_BANK_CAP` and `KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT` are the contract's constructor arguments and represent contract's balance cap and max limit for a single withdrawal request respectively.

As for the next variables:

- `SEPOLIA_RPC_URL` should be set to the RPC URL to deploy this contract to. For more information on how to get this value feel free to check [this guide from the Alchemy's documentation page](https://www.alchemy.com/docs/how-to-deploy-a-smart-contract-to-the-sepolia-testnet).
- `SEPOLIA_PRIVATE_KEY` should be set to your MetaMask's private key. For more information on how to get this value feel free to check [this guide on MetaMask's documentation page](https://www.google.com/search?client=safari&rls=en&q=metamask+private+key&ie=UTF-8&oe=UTF-8).
- `ETHERSCAN_API_KEY` should be set to your Etherscan's API key. For more information on how to get this value feel free to check [this guide on Etherscan's documentation page](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics).

Once you have your `.env` file ready, you're ready to deploy the contract by running the following command:

```bash
npm run deploy:sepolia
```

This will deploy the contract to the Sepolia testnet and will give you a contract address.

Once this is done, you can verify the contract with:

```bash
npm run verify:sepolia
```

This will verify the contract on Etherscan.

## Interacting with the Contract

This contract has been deployed and verified at the following address: [0xc8A84d9254f6d7C2f1Ed6B4a265E41a12b1d3Ee9](https://sepolia.etherscan.io/address/0xc8A84d9254f6d7C2f1Ed6B4a265E41a12b1d3Ee9#code)

First, head over to the Etherscan page of the contract and copy the ABI content.

Next, head over to the [Remix IDE](https://remix.ethereum.org/) and paste the ABI content into a `.abi` file with any name and leave this file open in the editor.

In the `Deploy & Run Transactions` page, `Injected Provider - MetaMask` in the Environment option and connect your wallet, **make sure to enable only the Sepolia network** when granting access.

Next, in the `At Address` textbox insert the contract's address and click the `At Address` button. You will receive a modal asking whether to load the contract with the ABI specification loaded, click `Accept` and you'll now have some buttons to interact with the contract.
