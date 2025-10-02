//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IRegistrarRenewalWithReferral {
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable;
}
