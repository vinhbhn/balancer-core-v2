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

pragma solidity ^0.7.1;

import "@openzeppelin/contracts/utils/SafeCast.sol";

import "hardhat/console.sol";

import "../../math/FixedPoint.sol";
import "../../math/LogExpMath.sol";

// This is a contract to emulate file-level functions. Convert to a library
// after the migration to solc v0.7.1.

/* solhint-disable private-vars-leading-underscore */

contract ConstantProductMath {
    using SafeCast for uint256;
    using SafeCast for int256;
    using FixedPoint for uint256;
    using FixedPoint for uint128;

    // Computes how many tokens can be taken out of a pool if `tokenAmountIn` are sent, given the
    // current balances and weights.
    function _outGivenIn(
        uint128 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint128 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint128 tokenAmountIn
    ) internal pure returns (uint128) {
        /**********************************************************************************************
        // outGivenIn                                                                                //
        // aO = tokenAmountOut                                                                       //
        // bO = tokenBalanceOut                                                                      //
        // bI = tokenBalanceIn              /      /            bI             \    (wI / wO) \      //
        // aI = tokenAmountIn    aO = bO * |  1 - | --------------------------  | ^            |     //
        // wI = tokenWeightIn               \      \       ( bI + aI )         /              /      //
        // wO = tokenWeightOut                                                                       //
        **********************************************************************************************/

        uint256 quotient = tokenBalanceIn.div(tokenBalanceIn.add(tokenAmountIn));
        uint256 weightRatio = tokenWeightIn.div(tokenWeightOut);
        uint256 ratio = FixedPoint.ONE.sub(
            LogExpMath.exp(int256(quotient), int256(weightRatio)).toUint256().toUint128()
        );

        return tokenBalanceOut.mul(ratio).toUint128();
    }

    // Computes how many tokens must be sent to a pool in order to take `tokenAmountOut`, given the
    // current balances and weights.
    function _inGivenOut(
        uint128 tokenBalanceIn,
        uint256 tokenWeightIn,
        uint128 tokenBalanceOut,
        uint256 tokenWeightOut,
        uint128 tokenAmountOut
    ) internal pure returns (uint128) {
        /**********************************************************************************************
        // inGivenOut                                                                                //
        // aO = tokenAmountOut                                                                       //
        // bO = tokenBalanceOut                                                                      //
        // bI = tokenBalanceIn              /  /            bO             \    (wO / wI)      \     //
        // aI = tokenAmountIn    aI = bI * |  | --------------------------  | ^            - 1  |    //
        // wI = tokenWeightIn               \  \       ( bO - aO )         /                   /     //
        // wO = tokenWeightOut                                                                       //
        **********************************************************************************************/

        uint256 quotient = tokenBalanceOut.div(tokenBalanceOut.sub(tokenAmountOut));
        uint256 weightRatio = tokenWeightOut.div(tokenWeightIn);
        uint256 ratio = LogExpMath.exp(int256(quotient), int256(weightRatio)).toUint256().toUint128().sub(
            FixedPoint.ONE
        );

        return tokenBalanceIn.mul(ratio).toUint128();
    }

    // Computes the invariant given the current balances and normalized weights.
    function _invariant(uint256[] memory normalizedWeights, uint128[] memory balances)
        internal
        pure
        returns (uint256 invariant)
    {
        require(normalizedWeights.length == balances.length, "ERR_BALANCES_LENGTH");

        invariant = FixedPoint.ONE;
        for (uint8 i = 0; i < normalizedWeights.length; i++) {
            invariant = invariant.mul(LogExpMath.exp(int256(balances[i]), int256(normalizedWeights[i])).toUint256());
        }
    }
}