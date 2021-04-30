import { Contract } from 'ethers';

import { BigNumberish } from '../../../../../lib/helpers/numbers';

import Vault from '../../vault/Vault';
import TokenList from '../../tokens/TokenList';
import { RawManagedWeightedPoolDeployment } from './types';
import ManagedWeightedPoolDeployer from './ManagedWeightedPoolDeployer';
import WeightedPool from '../weighted/WeightedPool';

export default class ManagedWeightedPool extends WeightedPool {
  instance: Contract;
  poolId: string;
  tokens: TokenList;
  weights: BigNumberish[];
  swapFeePercentage: BigNumberish;
  vault: Vault;
  assetManagers: string[];

  static async create(params: RawManagedWeightedPoolDeployment = {}): Promise<ManagedWeightedPool> {
    return ManagedWeightedPoolDeployer.deploy(params);
  }

  constructor(
    instance: Contract,
    poolId: string,
    vault: Vault,
    tokens: TokenList,
    weights: BigNumberish[],
    swapFeePercentage: BigNumberish,
    assetManagers: string[]
  ) {
    super(instance, poolId, vault, tokens, weights, swapFeePercentage, false);
    this.instance = instance;
    this.poolId = poolId;
    this.vault = vault;
    this.tokens = tokens;
    this.weights = weights;
    this.swapFeePercentage = swapFeePercentage;
    this.assetManagers = assetManagers;
  }
}
