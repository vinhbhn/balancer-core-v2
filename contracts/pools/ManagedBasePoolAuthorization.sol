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

import "../lib/helpers/Authentication.sol";
import "../vault/interfaces/IAuthorizer.sol";

import "./ManagedBasePool.sol";
import "../asset-managers/AssetManager.sol";

/**
 * @dev Base authorization layer implementation for Pools.
 *
 * The owner account can call some of the permissioned functions - access control of the rest is delegated to the
 * Authorizer. Note that this owner is immutable: more sophisticated permission schemes, such as multiple ownership,
 * granular roles, etc., could be built on top of this by making the owner a smart contract.
 *
 * Access control of all other permissioned functions is delegated to an Authorizer. It is also possible to delegate
 * control of *all* permissioned functions to the Authorizer by setting the owner address to `_DELEGATE_OWNER`.
 */
abstract contract ManagedBasePoolAuthorization is Authentication {
    // Allow separate control of asset management, vs fees and pausing
    address private immutable _owner;
    address private immutable _assetController;

    address private constant _DELEGATE_OWNER = 0xBA1BA1ba1BA1bA1bA1Ba1BA1ba1BA1bA1ba1ba1B;

    constructor(address owner, address assetController) {
        _owner = owner;
        _assetController = assetController;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    function getAssetController() public view returns (address) {
        return _assetController;
    }

    function getAuthorizer() external view returns (IAuthorizer) {
        return _getAuthorizer();
    }

    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        if (getOwner() != _DELEGATE_OWNER) {
            if (_isOwnerOnlyAction(actionId)) {
                return msg.sender == getOwner();
            } else if (_isAssetControllerOnlyAction(actionId)) {
                return msg.sender == getAssetController();
            }
        }

        // Non-owner actions are always processed via the Authorizer, as "owner only" ones are when delegated.
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }

    function _isOwnerOnlyAction(bytes32 actionId) private view returns (bool) {
        // This implementation hardcodes the setSwapFeePercentage action identifier.
        return actionId == getActionId(ManagedBasePool.setSwapFeePercentage.selector);
    }

    function _isAssetControllerOnlyAction(bytes32 actionId) private view returns (bool) {
        // This implementation hardcodes the setInvestablePercent action identifier.
        return actionId == getActionId(AssetManager.setInvestablePercent.selector);
    }

    function _getAuthorizer() internal view virtual returns (IAuthorizer);
}
