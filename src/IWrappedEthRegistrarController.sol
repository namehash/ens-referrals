//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";

interface IWrappedEthRegistrarController {
    function renew(string calldata name, uint256 duration) external payable;

    function rentPrice(string memory name, uint256 duration) external view returns (IPriceOracle.Price memory price);
}
