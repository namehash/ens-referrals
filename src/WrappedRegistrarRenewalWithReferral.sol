//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

/**
 * @title WrappedRegistrarRenewalWithReferral
 * @notice A contract for renewing ENS names via the WrappedEthRegistrarController with referral tracking.
 *
 * This contract enables ENS name renewals through the wrapped registrar controller while tracking
 * referral information. It achieves its goals by:
 *
 * 1. Calculating the instantaneous renewal price using the WrappedEthRegistrarController
 * 2. Executing the renewal through the WrappedEthRegistrarController with the provided payment
 * 3. Retrieving the updated expiry time from the NameWrapper contract
 * 4. Emitting a NameRenewed event that includes referral data for tracking purposes
 * 5. Refunding any excess payment back to the caller
 *
 * @dev This contract is Ownable to enable future Enscribe compatibility for on-chain management.
 *      See: https://www.enscribe.xyz
 */
contract WrappedRegistrarRenewalWithReferral is
    IRegistrarRenewalWithReferral,
    Ownable
{
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;
    INameWrapper immutable NAME_WRAPPER;

    /// @notice Emitted when a name is renewed.
    ///
    /// @param label The label of the name.
    /// @param labelhash The keccak256 hash of the label.
    /// @param cost The cost of the name.
    /// @param expires The expiry time of the name.
    /// @param referrer The referrer of the registration.
    event NameRenewed(
        string label,
        bytes32 indexed labelhash,
        uint256 cost,
        uint256 expires,
        bytes32 referrer
    );

    constructor(
        IWrappedEthRegistrarController _wrappedEthRegistrarController,
        INameWrapper _nameWrapper
    ) Ownable(msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
        NAME_WRAPPER = _nameWrapper;
    }

    /**
     * @notice Renews an ENS name with referral tracking
     * @param label The label of the ENS name to renew
     * @param duration The duration to extend the registration
     * @param referrer The referrer for tracking purposes
     * @dev Gas usage: ~136k
     */
    function renew(
        string calldata label,
        uint256 duration,
        bytes32 referrer
    ) external payable {
        // 1. calculate instantaneous price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(label, duration);

        // 2. WrappedEthRegistrarController#renew(), which handles payment invariants
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(label, duration);

        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 labelHash = keccak256(bytes(label));

        // 3. Retrieve new expiry from NameWrapper
        (,,uint64 expiry) = NAME_WRAPPER.getData(uint256(labelHash));

        // 4. emit NameRenewed
        emit NameRenewed(label, labelHash, price.base, expiry, referrer);

        // 5. refund msg.sender any leftover balance
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}
