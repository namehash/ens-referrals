//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IETHRegistrarController} from "ens-contracts/ethregistrar/IETHRegistrarController.sol";
import {IWrappedEthRegistrarController} from "./IWrappedEthRegistrarController.sol";
import {IRegistrarRenewalWithReferral} from "./IRegistrarRenewalWithReferral.sol";

contract UniversalRegistrarRenewalWithReferrer is
    IRegistrarRenewalWithReferral,
    Ownable
{
    IWrappedEthRegistrarController immutable WRAPPED_ETH_REGISTRAR_CONTROLLER;
    IETHRegistrarController immutable UNWRAPPED_ETH_REGISTRAR_CONTROLLER;

    constructor(
        IWrappedEthRegistrarController _wrappedEthRegistrarController,
        IETHRegistrarController _unwrappedEthRegistrarController
    ) Ownable(msg.sender) {
        WRAPPED_ETH_REGISTRAR_CONTROLLER = _wrappedEthRegistrarController;
        UNWRAPPED_ETH_REGISTRAR_CONTROLLER = _unwrappedEthRegistrarController;
    }

    function renew(
        string calldata label,
        uint256 duration,
        bytes32 referrer
    ) external payable {
        // 1. renew the name in the latest EthRegistrarController, which emits referrer
        UNWRAPPED_ETH_REGISTRAR_CONTROLLER.renew{value: msg.value}(
            label,
            duration,
            referrer
        );

        // 2. bump the WrappedEthRegistrarController so NameWrapper gets the new expiry
        WRAPPED_ETH_REGISTRAR_CONTROLLER.renew(label, 0);

        // 3. refund msg.sender any leftover balance
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }
}