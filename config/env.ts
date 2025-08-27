import 'dotenv/config';

export const KIPU_BANK_CAP = process.env.KIPU_BANK_CAP ?
  parseInt(process.env.KIPU_BANK_CAP, 10) :
  undefined;

export const KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT = process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT ?
  parseInt(process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT, 10) :
  undefined;

export const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL!;
export const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY!;
export const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY!;
