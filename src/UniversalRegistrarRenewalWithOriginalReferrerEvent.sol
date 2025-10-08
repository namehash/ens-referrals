//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {ReverseClaimer} from "ens-contracts/reverseRegistrar/ReverseClaimer.sol";
import {IETHRegistrarController} from "ens-contracts/ethregistrar/IETHRegistrarController.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title UniversalRegistrarRenewalWithOriginalReferrerEvent
 * @notice A universal renewal contract that works with both wrapped and unwrapped .eth subnames while
 * tracking referrals.
 *
 * This contract provides a unified interface for renewing .eth subnames regardless of whether they are
 * wrapped or unwrapped, while maintaining referral tracking capabilities. It achieves its goals by:
 *
 * 1. Renewing the name through the unwrapped ETHRegistrarController, which handles referral emission
 *    and extends the underlying registration expiry in the base registrar
 * 2. Synchronizing the WrappedEthRegistrarController (with 0 duration) to ensure the NameWrapper
 *    contract receives the updated expiry information from the base registrar
 * 3. Refunding any excess payment back to the caller
 *
 * This approach ensures that both wrapped and unwrapped names are properly renewed with a single
 * transaction, maintaining consistency across the ENS ecosystem while preserving referral data.
 *
 * @dev This contract extends ReverseClaimer to enable future contract naming compatibility.
 */
contract UniversalRegistrarRenewalWithOriginalReferrerEvent is IRegistrarRenewalWithReferral, ReverseClaimer {
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;
    IETHRegistrarController immutable UNWRAPPED_ETH_REGISTRAR_CONTROLLER;

    constructor(
        ENS ens,
        IWrappedEthRegistrarController _wrappedEthRegistrarController,
        IETHRegistrarController _unwrappedEthRegistrarController
    ) ReverseClaimer(ens, msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
        UNWRAPPED_ETH_REGISTRAR_CONTROLLER = _unwrappedEthRegistrarController;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the .eth subname to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer for tracking purposes
     * @dev Gas usage: ~129k
     */
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable {
        // 1. renew the name in the latest EthRegistrarController, which emits referrer
        UNWRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(label, duration, referrer);

        // 2. bump the WrappedEthRegistrarController so NameWrapper gets the new expiry
        // NOTE: NameWrapper.renew() calls BaseRegistrar.renew() and then no-ops if name is not wrapped.
        // Combined with a 0 duration, if a name is wrapped, the NameWrapper updates its internal expiry
        // correctly, fetching the latest value from the BaseRegistrar.
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew(label, 0);

        // 3. refund msg.sender any leftover balance
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
