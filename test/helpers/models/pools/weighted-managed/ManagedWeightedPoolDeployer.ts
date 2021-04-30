import { ethers } from 'hardhat';
import { Contract } from 'ethers';

import * as expectEvent from '../../../expectEvent';
import { deploy } from '../../../../../lib/helpers/deploy';

import Vault from '../../vault/Vault';
import ManagedWeightedPool from '../weighted-managed/ManagedWeightedPool';
import VaultDeployer from '../../vault/VaultDeployer';
import TypesConverter from '../../types/TypesConverter';
import { RawManagedWeightedPoolDeployment, ManagedWeightedPoolDeployment } from '../weighted-managed/types';

const NAME = 'Balancer Pool Token';
const SYMBOL = 'BPT';

export default {
  async deploy(params: RawManagedWeightedPoolDeployment): Promise<ManagedWeightedPool> {
    const deployment = TypesConverter.toManagedWeightedPoolDeployment(params);
    const vault = await VaultDeployer.deploy(TypesConverter.toRawVaultDeployment(params));
    const pool = await (params.fromFactory ? this._deployFromFactory : this._deployStandalone)(deployment, vault);

    const { tokens, weights, swapFeePercentage, assetManagers } = deployment;
    const poolId = await pool.getPoolId();
    return new ManagedWeightedPool(pool, poolId, vault, tokens, weights, swapFeePercentage, assetManagers);
  },

  async _deployStandalone(params: ManagedWeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const {
      tokens,
      weights,
      swapFeePercentage,
      pauseWindowDuration,
      bufferPeriodDuration,
      owner,
      assetManagers,
      from,
    } = params;
    return deploy('ManagedWeightedPool', {
          args: [
            vault.address,
            NAME,
            SYMBOL,
            tokens.addresses,
            weights,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            TypesConverter.toAddress(owner),
            assetManagers
          ],
          from,
        });
  },

  async _deployFromFactory(params: ManagedWeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const { tokens, weights, swapFeePercentage, owner, assetManagers, from } = params;

    const factory = await deploy('ManagedWeightedPoolFactory', { args: [vault.address], from });
    const tx = await factory.create(
      NAME,
      SYMBOL,
      tokens.addresses,
      weights,
      swapFeePercentage,
      TypesConverter.toAddress(owner),
      assetManagers
    );
    const receipt = await tx.wait();
    const event = expectEvent.inReceipt(receipt, 'PoolCreated');
    return ethers.getContractAt('ManagedWeightedPool', event.args.pool);
  },
};
