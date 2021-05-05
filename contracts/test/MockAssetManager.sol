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

pragma solidity ^0.7.0;

import "../asset-managers/IAssetManager.sol";
import "../lib/helpers/BalancerErrors.sol";

contract MockAssetManager is IAssetManager {
    uint256 public constant MINIMUM_INVESTABLE_PERCENT = 1e17; // 10%

    modifier onlyPoolController(bytes32 poolId) {
        address poolAddress = address((uint256(poolId) >> (12 * 8)) & (2**(20 * 8) - 1));
        _require(msg.sender == poolAddress, Errors.CALLER_NOT_POOL);
        _;
    }

    function setInvestablePercent(bytes32 poolId, uint256 investablePercent) external override onlyPoolController(poolId) {
        _require(investablePercent >= MINIMUM_INVESTABLE_PERCENT, Errors.INVESTABLE_PERCENT_BELOW_MINIMUM);
    }
}
