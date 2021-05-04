import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { BigNumberish } from '../../../../../lib/helpers/numbers';

import TokenList from '../../tokens/TokenList';
import { Account } from '../../types/types';

export type RawManagedWeightedPoolDeployment = {
  tokens?: TokenList;
  weights?: BigNumberish[];
  swapFeePercentage?: BigNumberish;
  pauseWindowDuration?: BigNumberish;
  bufferPeriodDuration?: BigNumberish;
  assetManagers?: string[];
  owner?: Account;
  assetController?: Account;
  admin?: SignerWithAddress;
  from?: SignerWithAddress;
  fromFactory?: boolean;
};

export type ManagedWeightedPoolDeployment = {
  tokens: TokenList;
  weights: BigNumberish[];
  swapFeePercentage: BigNumberish;
  pauseWindowDuration: BigNumberish;
  bufferPeriodDuration: BigNumberish;
  owner: Account;
  assetController: Account;
  assetManagers: string[];
  admin?: SignerWithAddress;
  from?: SignerWithAddress;
};
