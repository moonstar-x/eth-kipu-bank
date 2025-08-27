import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import constructorArguments from '../../arguments/KipuBank';

export default buildModule('KipuBankModule', (m) => {
  const bank = m.contract('KipuBank', constructorArguments);
  return { bank };
});
