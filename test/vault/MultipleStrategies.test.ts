import { ethers } from 'hardhat';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { MAX_UINT256 } from '../helpers/constants';
import { expectBalanceChange } from '../helpers/tokenBalance';
import { TokenList, deployTokens } from '../helpers/tokens';
import { deploy } from '../../scripts/helpers/deploy';
import { setupPool } from '../../scripts/helpers/pools';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

describe('Vault - multiple trading strategies interfaces', () => {
  let controller: SignerWithAddress;

  let vault: Contract;
  let mockStrategy: Contract;
  let mockScript: Contract;

  let trader: SignerWithAddress;
  let tokens: TokenList = {};

  let poolIdPair: string;
  let poolIdTuple: string;

  before('setup', async () => {
    [, controller, trader] = await ethers.getSigners();
  });

  beforeEach(async () => {
    vault = await deploy('Vault');
    tokens = await deployTokens(['DAI', 'TEST']);

    mockStrategy = await deploy('MockTradingStrategy');
    mockScript = await deploy('MockTradeScript');

    poolIdPair = await setupPool(vault, mockStrategy, 0, tokens, controller, [
      ['DAI', (1e18).toString()],
      ['TEST', (1e18).toString()],
    ]);

    poolIdTuple = await setupPool(vault, mockStrategy, 1, tokens, controller, [
      ['DAI', (1e18).toString()],
      ['TEST', (1e18).toString()],
    ]);

    // Mint tokens for trader
    await tokens.DAI.mint(trader.address, (300e18).toString());
    await tokens.TEST.mint(trader.address, (300e18).toString());

    // Approve trade script by trader
    await tokens.DAI.connect(trader).approve(vault.address, MAX_UINT256);
    await tokens.TEST.connect(trader).approve(vault.address, MAX_UINT256);

    await vault.connect(trader).authorizeOperator(mockScript.address);
  });

  it('has the correct curve', async () => {
    expect(await vault.getStrategy(poolIdPair)).to.have.members([mockStrategy.address, 0]);
    expect(await vault.getStrategy(poolIdTuple)).to.have.members([mockStrategy.address, 1]);
  });

  it('trades with tuple strategy pool', async () => {
    const diffs = [
      {
        token: tokens.DAI.address,
        vaultDelta: 0,
        amountIn: 0,
      },
      {
        token: tokens.TEST.address,
        vaultDelta: 0,
        amountIn: 0,
      },
    ];

    const swaps = [
      {
        poolId: poolIdTuple,
        tokenIn: { tokenDiffIndex: 1, amount: (1e18).toString() },
        tokenOut: { tokenDiffIndex: 0, amount: (1e18).toString() },
      },
    ];

    const [preDAIBalance, preTESTBalance] = await vault.getPoolTokenBalances(poolIdTuple, [
      tokens.DAI.address,
      tokens.TEST.address,
    ]);

    await expectBalanceChange(
      async () => {
        await mockScript
          .connect(trader)
          .batchSwap(vault.address, [0, (1e18).toString()], diffs, swaps, trader.address, trader.address, true);
      },
      trader,
      tokens,
      { DAI: 1e18, TEST: -1e18 }
    );

    const [postDAIBalance, postTESTBalance] = await vault.getPoolTokenBalances(poolIdTuple, [
      tokens.DAI.address,
      tokens.TEST.address,
    ]);

    // DAI pool balance should decrease, TEST pool balance should increase
    expect(postDAIBalance.sub(preDAIBalance)).to.equal((-1e18).toString());
    expect(postTESTBalance.sub(preTESTBalance)).to.equal((1e18).toString());
  });

  it('trades with pair strategy product pool', async () => {
    const diffs = [
      {
        token: tokens.DAI.address,
        vaultDelta: 0,
        amountIn: 0,
      },
      {
        token: tokens.TEST.address,
        vaultDelta: 0,
        amountIn: 0,
      },
    ];

    const swaps = [
      {
        poolId: poolIdPair,
        tokenIn: { tokenDiffIndex: 1, amount: (1e18).toString() },
        tokenOut: { tokenDiffIndex: 0, amount: (1e18).toString() },
      },
    ];

    const [preDAIBalance, preTESTBalance] = await vault.getPoolTokenBalances(poolIdTuple, [
      tokens.DAI.address,
      tokens.TEST.address,
    ]);

    await expectBalanceChange(
      async () => {
        // Send tokens & swap - would normally happen in the same tx
        await mockScript
          .connect(trader)
          .batchSwap(vault.address, [0, (1e18).toString()], diffs, swaps, trader.address, trader.address, true);
      },
      trader,
      tokens,
      { DAI: 1e18, TEST: -1e18 }
    );

    const [postDAIBalance, postTESTBalance] = await vault.getPoolTokenBalances(poolIdPair, [
      tokens.DAI.address,
      tokens.TEST.address,
    ]);

    // DAI pool balance should decrease, TEST pool balance should increase
    expect(postDAIBalance.sub(preDAIBalance)).to.equal((-1e18).toString());
    expect(postTESTBalance.sub(preTESTBalance)).to.equal((1e18).toString());
  });
});