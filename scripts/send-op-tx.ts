import { network } from 'hardhat';
import logger from '@moonstar-x/logger';

const { viem } = await network.connect({
  network: 'hardhatOp',
  chainType: 'op'
});

logger.log('Sending transaction using the OP chain type');

const publicClient = await viem.getPublicClient();
const [senderClient] = await viem.getWalletClients();

logger.log('Sending 1 wei from', senderClient.account.address, 'to itself');

const l1Gas = await publicClient.estimateL1Gas({
  account: senderClient.account.address,
  to: senderClient.account.address,
  value: 1n
});

logger.log('Estimated L1 gas:', l1Gas);

logger.log('Sending L2 transaction');
const tx = await senderClient.sendTransaction({
  to: senderClient.account.address,
  value: 1n
});

await publicClient.waitForTransactionReceipt({ hash: tx });

logger.log('Transaction sent successfully');
