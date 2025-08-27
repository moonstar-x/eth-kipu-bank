import { KIPU_BANK_CAP, KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT } from '../config/env';

if (!KIPU_BANK_CAP || !KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT) {
  throw new Error('Constructor values not provided in .env.');
}

export default [
  KIPU_BANK_CAP, KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT
];
