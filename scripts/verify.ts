import hre from 'hardhat';
import { verifyContract } from '@nomicfoundation/hardhat-verify/verify';
import constructorArguments from '../arguments/KipuBank';
import deployedAddressess from '../ignition/deployments/chain-11155111/deployed_addresses.json';

verifyContract(
  {
    address: deployedAddressess['KipuBankModule#KipuBank'],
    constructorArgs: constructorArguments,
    provider: 'etherscan'
  },
  hre
);
