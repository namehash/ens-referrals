//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";

/**
 * ABI for the WrappedEthRegistrarController.
 * @dev Mainnet Address: 0x253553366da8546fc250f225fe3d25d0c782303b
 */
interface IWrappedEthRegistrarController {
    function renew(string calldata name, uint256 duration) external payable;
    function rentPrice(string memory name, uint256 duration) external view returns (IPriceOracle.Price memory price);
}
