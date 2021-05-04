import { Contract } from 'ethers';

import { BigNumberish } from '../../../../../lib/helpers/numbers';

import Vault from '../../vault/Vault';
import TokenList from '../../tokens/TokenList';
import { RawManagedWeightedPoolDeployment } from './types';
import ManagedWeightedPoolDeployer from './ManagedWeightedPoolDeployer';
import WeightedPool from '../weighted/WeightedPool';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { Account } from '../../../models/types/types';

export default class ManagedWeightedPool extends WeightedPool {
  instance: Contract;
  poolId: string;
  tokens: TokenList;
  weights: BigNumberish[];
  swapFeePercentage: BigNumberish;
  vault: Vault;
  owner: Account;
  assetController: Account;
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
    owner: Account,
    assetController: Account,
    assetManagers: string[]
  ) {
    super(instance, poolId, vault, tokens, weights, swapFeePercentage, false);
    this.instance = instance;
    this.poolId = poolId;
    this.vault = vault;
    this.tokens = tokens;
    this.weights = weights;
    this.swapFeePercentage = swapFeePercentage;
    this.owner = owner;
    this.assetController = assetController;
    this.assetManagers = assetManagers;
  }

  async getOwner(): Promise<Account> {
    return this.instance.getOwner();
  }

  async getAssetController(): Promise<Account> {
    return this.instance.getAssetController();
  }

  async setSwapFeePercentage(from: SignerWithAddress, swapFeePercentage: BigNumberish): Promise<void> {
    return this.instance.connect(from).setSwapFeePercentage(swapFeePercentage);
  }

  async setInvestablePercent(from: SignerWithAddress, token: string, investablePercent: BigNumberish): Promise<void> {
    return this.instance.connect(from).setInvestablePercent(token, investablePercent);
  }
}
