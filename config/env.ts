import 'dotenv/config';

export const KIPU_BANK_CAP = process.env.KIPU_BANK_CAP ?
  parseInt(process.env.KIPU_BANK_CAP, 10) :
  undefined;

export const KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT = process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT ?
  parseInt(process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT, 10) :
  undefined;

// Note: Default values are dummy values to satisfy Hardhat so tests can run.
export const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL ?? 'https://eth-sepolia.g.alchemy.com';
export const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY ?? '27fcf96996e466a3df40ce620740902eaf92fc606627c79bf4a68dfb7abe6d1e';
export const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY ?? 'ETHERSCAN_API_KEY';
