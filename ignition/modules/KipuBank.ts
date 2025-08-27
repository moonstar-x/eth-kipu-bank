import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { KIPU_BANK_CAP, KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT } from '../../config/env.js';

export default buildModule('KipuBankModule', (m) => {
  if (!KIPU_BANK_CAP || !KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT) {
    throw new Error('Constructor values not provided in .env.');
  }

  const bank = m.contract('KipuBank', [KIPU_BANK_CAP, KIPU_BANK_MAX_SINGLE_WITHDRAW_LIMIT]);
  return { bank };
});
