//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title UniversalRegistrarRenewalWithSimpleReferrerEvent
 * @notice A simplified contract for renewing ENS names via the WrappedEthRegistrarController with referral tracking.
 *
 * This contract provides a simplified renewal process that:
 * 1. Calls WRAPPED_ETH_REGISTRAR_CONTROLLER.renew()
 * 2. Emits the RenewalReferred event
 * 3. Refunds the sender
 */
contract UniversalRegistrarRenewalWithReferrer is IRegistrarRenewalWithReferral, ReverseClaimer {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;

    /// @notice Emitted when a name is renewed with a referrer.
    ///
    /// @param labelHash The keccak256 hash of the .eth subname label
    /// @param referrer The referrer of the registration.
    event RenewalReferred(bytes32 indexed labelHash, bytes32 referrer, uint256 cost, uint256 duration);

    constructor(ENS ens, IWrappedEthRegistrarController _wrappedEthRegistrarController) ReverseClaimer(ens, msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the .eth subname to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer for tracking purposes
     * @dev Gas usage: ~122k
     */
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable {
        uint256 prevBalance = address(this).balance;

        // 1. Call WRAPPED_ETH_REGISTRAR_CONTROLLER.renew()
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(label, duration);

        // 2. Emit the RenewalReferred event with actual cost spent
        uint256 cost = prevBalance - address(this).balance;
        emit RenewalReferred(keccak256(bytes(label)), referrer, cost, duration);

        // 3. Refund sender
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
