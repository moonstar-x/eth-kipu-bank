import 'dotenv/config';

export const KIPU_BANK_CAP = process.env.KIPU_BANK_CAP ?
  parseInt(process.env.KIPU_BANK_CAP, 10) :
  undefined;

export const KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT = process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT ?
  parseInt(process.env.KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT, 10) :
  undefined;
