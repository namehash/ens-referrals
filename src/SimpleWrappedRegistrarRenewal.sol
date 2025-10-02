//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title SimpleWrappedRegistrarRenewal
 * @notice A simplified contract for renewing ENS names via the WrappedEthRegistrarController with referral tracking.
 *
 * This contract provides a simplified renewal process that:
 * 1. Calls WRAPPED_ETH_REGISTRAR_CONTROLLER.renew()
 * 2. Emits the RenewalReferred event
 * 3. Refunds the sender
 *
 * @dev This version is more complex for an indexer to implement, as the information required to attribute
 * a referral is spread across two separate events that must be consolidated. The indexer would track all
 * RenewalReferred events and then, when encountering one, fetch the associated WrappedEthRegistrarController#NameRenewed
 * event in the same transaction for the specified label in order to determine the duration referred
 * to attribute to the referrer in question.
 */
contract SimpleWrappedRegistrarRenewal is IRegistrarRenewalWithReferral, Ownable {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;

    /// @notice Emitted when a name is renewed with a referrer.
    ///
    /// @param label The label of the name.
    /// @param referrer The referrer of the registration.
    event RenewalReferred(string label, bytes32 referrer);

    constructor(IWrappedEthRegistrarController _wrappedEthRegistrarController) Ownable(msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the ENS name to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer for tracking purposes
     * @dev Gas usage: ~109k
     */
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable {
        // 1. Call WRAPPED_ETH_REGISTRAR_CONTROLLER.renew()
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(label, duration);

        // 2. Emit the RenewalReferred event
        emit RenewalReferred(label, referrer);

        // 3. Refund sender
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
