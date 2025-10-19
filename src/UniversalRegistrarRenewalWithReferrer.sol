//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title UniversalRegistrarRenewalWithReferrer
 * @notice A contract for renewing ENS names via the WrappedEthRegistrarController with referral tracking.
 *
 * This contract provides a simplified renewal process that:
 * 1. Calls WRAPPED_ETH_REGISTRAR_CONTROLLER.renew()
 * 2. Emits the RenewalReferred event with both label and indexed labelHash for searchability
 * 3. Refunds the sender
 */
contract UniversalRegistrarRenewalWithReferrer is IRegistrarRenewalWithReferral, ReverseClaimer {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;

    /// @notice Emitted when a name is renewed with a referrer.
    ///
    /// @param label The .eth subname label
    /// @param labelHash The keccak256 hash of the .eth subname label
    /// @param cost The actual cost of the renewal
    /// @param duration The duration of the renewal
    /// @param referrer The referrer of the renewal
    event RenewalReferred(string label, bytes32 indexed labelHash, uint256 cost, uint256 duration, bytes32 referrer);

    constructor(ENS ens, IWrappedEthRegistrarController _wrappedEthRegistrarController) ReverseClaimer(ens, msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the .eth subname to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer of the renewal
     * @dev Gas usage: ~122k
     */
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable {
        // 1. Call WRAPPED_ETH_REGISTRAR_CONTROLLER.renew() & infer cost
        uint256 prevBalance = address(this).balance;
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: prevBalance}(label, duration);
        uint256 currBalance = address(this).balance;
        uint256 cost = prevBalance - currBalance;

        // 2. Emit the RenewalReferred event with actual cost spent and indexed labelHash for searchability
        // NOTE: we emit `duration` instead of `expiry` to avoid the gas cost of reading the new
        // expiry from the Registry
        emit RenewalReferred(label, keccak256(bytes(label)), cost, duration, referrer);

        // 3. Refund sender any unspent wei, along with any excess contract balance
        if (currBalance > 0) {
            payable(msg.sender).transfer(currBalance);
        }
    }

    receive() external payable {}
}
