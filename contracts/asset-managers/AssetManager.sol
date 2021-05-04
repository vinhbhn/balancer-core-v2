// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import "../vault/interfaces/IVault.sol";
import "../lib/openzeppelin/IERC20.sol";
import "../lib/math/Math.sol";
import "../lib/openzeppelin/SafeCast.sol";

import "../lib/helpers/BalancerErrors.sol";

pragma solidity ^0.7.0;

abstract contract AssetManager {
    using Math for uint256;
    using SafeCast for uint256;

    /// @notice The Balancer Vault contract
    IVault public immutable vault;

    /// @notice The token which this asset manager is investing
    IERC20 public immutable token;

    uint256 public constant MINIMUM_INVESTABLE_PERCENT = 1e17; // 10%

    /// @notice the total AUM of tokens that the asset manager is aware it has earned
    uint256 public totalAUM;
    /// @notice the total number of shares with claims on the asset manager's AUM
    uint256 public totalSupply;

    // mapping from poolIds to the number of owned shares
    mapping(bytes32 => uint256) private _balances;
    // mapping from poolIds to the fraction of that pool's assets which may be invested
    mapping(bytes32 => uint256) private _investablePercent;

    constructor(IVault _vault, address _token) {
        IERC20(_token).approve(address(_vault), type(uint256).max);
        vault = _vault;
        token = IERC20(_token);
    }

    modifier onlyPoolController(bytes32 poolId) {
        address poolAddress = address((uint256(poolId) >> (12 * 8)) & (2**(20 * 8) - 1));
        _require(msg.sender == poolAddress, Errors.CALLER_NOT_POOL);
        _;
    }

    /**
     * @param poolId - The id of the pool of interest
     * @return The amount of the underlying tokens which are owned by the specified pool
     */
    function balanceOf(bytes32 poolId) public view returns (uint256) {
        return _balances[poolId].mul(totalAUM).divDown(totalSupply);
    }

    /**
     * @param poolId - The id of the pool of interest
     * @return the number of shares owned by the specified pool
     */
    function balanceOfShares(bytes32 poolId) public view returns (uint256) {
        return _balances[poolId];
    }

    function _mint(bytes32 poolId, uint256 amount) internal {
        _balances[poolId] = _balances[poolId].add(amount);
        totalSupply = totalSupply.add(amount);
    }

    function _burn(bytes32 poolId, uint256 amount) internal {
        _balances[poolId] = _balances[poolId].sub(amount);
        totalSupply = totalSupply.sub(amount);
    }

    // Investment configuration

    function setInvestablePercent(bytes32 poolId, uint256 investablePercent) external onlyPoolController(poolId) {
        _require(investablePercent >= MINIMUM_INVESTABLE_PERCENT, Errors.INVESTABLE_PERCENT_BELOW_MINIMUM);

        _investablePercent[poolId] = investablePercent;
    }

    function _getTargetInvestment(
        uint256 cash,
        uint256 managed,
        uint256 investablePercent
    ) private pure returns (uint256) {
        return (cash.add(managed)).mul(investablePercent).divDown(1e18);
    }

    /**
     * @return The difference in token between the target investment
     * and the currently invested amount (i.e. the amount that can be invested)
     */
    function maxInvestableBalance(bytes32 poolId) public view returns (int256) {
        uint256 investablePercent = _investablePercent[poolId];
        uint256 poolCash;
        uint256 poolManaged;

        (poolCash, poolManaged, , ) = vault.getPoolTokenInfo(poolId, token);
        int256 maxInvestable = int256(_getTargetInvestment(poolCash, poolManaged, investablePercent)) -
            int256(poolManaged);
        return maxInvestable;
    }

    /**
     * @return the target investment percent for the pool
     */
    function getInvestablePercent(bytes32 poolId) public view returns (uint256) {
        return _investablePercent[poolId];
    }

    // Reporting

    /**
     * @notice Updates the Vault on the value of the pool's investment returns
     * @dev To be called following a call to realizeGains
     * @param poolId - the id of the pool for which to update the balance
     */
    function updateBalanceOfPool(bytes32 poolId) public {
        uint256 managedBalance = balanceOf(poolId);

        IVault.PoolBalanceOp memory transfer = IVault.PoolBalanceOp(
            IVault.PoolBalanceOpKind.UPDATE,
            poolId,
            token,
            managedBalance
        );
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = (transfer);

        vault.managePoolBalance(ops);
    }

    // Deposit / Withdraw

    /**
     * @dev Transfers capital into the asset manager, and then invests it
     * @param poolId - the id of the pool depositing funds into this asset manager
     * @param amount - the amount of tokens being deposited
     */
    function capitalIn(bytes32 poolId, uint128 amount) public {
        uint256 aum = readAUM();

        int256 maxAmountIn = maxInvestableBalance(poolId);
        _require(maxAmountIn >= amount, Errors.INVESTMENT_AMOUNT_EXCEEDS_TARGET);

        // Pull funds from the vault
        IVault.PoolBalanceOp memory transfer = IVault.PoolBalanceOp(
            IVault.PoolBalanceOpKind.WITHDRAW,
            poolId,
            token,
            amount
        );
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = (transfer);

        vault.managePoolBalance(ops);

        uint256 mintAmount = _invest(poolId, amount, aum);

        // Update with gains and add deposited tokens from AUM
        totalAUM = aum.add(amount);
        // mint pool share of the asset manager
        _mint(poolId, mintAmount);
    }

    /**
     * @notice Divests capital back to the asset manager and then sends it to the vault
     * @param poolId - the id of the pool withdrawing funds from this asset manager
     * @param amount - the amount of tokens to withdraw to the vault
     */
    function capitalOut(bytes32 poolId, uint256 amount) public {
        uint256 aum = readAUM();
        uint256 sharesToBurn = totalSupply.mul(amount).divUp(aum);
        _redeemShares(poolId, sharesToBurn, aum);
    }

    /**
     * @notice Divests capital back to the asset manager and then sends it to the vault
     * @param poolId - the id of the pool withdrawing funds from this asset manager
     * @param shares - the amount of shares being burned
     */
    function redeemShares(bytes32 poolId, uint256 shares) public {
        _redeemShares(poolId, shares, readAUM());
    }

    /**
     * @notice Divests capital back to the asset manager and then sends it to the vault
     * @param poolId - the id of the pool withdrawing funds from this asset manager
     * @param shares - the amount of shares being burned
     */
    function _redeemShares(
        bytes32 poolId,
        uint256 shares,
        uint256 aum
    ) private {
        uint256 tokensOut = _divest(poolId, shares, aum);

        int256 maxAmountOut = -1 * maxInvestableBalance(poolId);
        _require(maxAmountOut >= tokensOut.toInt256(), Errors.INSUFFICIENT_BALANCE_AFTER_WITHDRAWAL);

        // Send funds back to the vault
        IVault.PoolBalanceOp memory transfer = IVault.PoolBalanceOp(
            IVault.PoolBalanceOpKind.DEPOSIT,
            poolId,
            token,
            tokensOut
        );
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = (transfer);

        vault.managePoolBalance(ops);

        // Update with gains and remove withdrawn tokens from AUM
        totalAUM = aum.sub(tokensOut);
        _burn(poolId, shares);
    }

    /**
     * @notice Checks invested balance and updates AUM appropriately
     */
    function realizeGains() public {
        totalAUM = readAUM();
    }

    /**
     * @dev Invests capital inside the asset manager
     * @param poolId - the id of the pool depositing funds into this asset manager
     * @param amount - the amount of tokens being deposited
     * @return the number of shares to mint for the pool
     */
    function _invest(
        bytes32 poolId,
        uint256 amount,
        uint256 aum
    ) internal virtual returns (uint256);

    /**
     * @dev Divests capital back to the asset manager
     * @param poolId - the id of the pool withdrawing funds from this asset manager
     * @param shares - the amount of shares being burned
     * @return the number of tokens to return to the vault
     */
    function _divest(
        bytes32 poolId,
        uint256 shares,
        uint256 aum
    ) internal virtual returns (uint256);

    /**
     * @return the current assets under management of this asset manager
     */
    function readAUM() public view virtual returns (uint256);
}
