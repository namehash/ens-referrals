//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {UniversalRegistrarRenewalWithReferrer} from "../src/UniversalRegistrarRenewalWithReferrer.sol";

contract DeployScript is Script {
    function run() public {
        // Determine network and addresses
        (ENS ens, IWrappedEthRegistrarController wrappedController) = getNetworkAddresses();

        console.log("Deploying UniversalRegistrarRenewalWithReferrer...");
        console.log("ENS Registry:", address(ens));
        console.log("Wrapped Controller:", address(wrappedController));

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the contract
        UniversalRegistrarRenewalWithReferrer renewal = new UniversalRegistrarRenewalWithReferrer(ens, wrappedController);

        vm.stopBroadcast();

        console.log("UniversalRegistrarRenewalWithReferrer deployed at:", address(renewal));
    }

    function getNetworkAddresses() internal view returns (ENS ens, IWrappedEthRegistrarController wrappedController) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
            wrappedController = IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
        } else if (chainId == 11155111) {
            // Sepolia testnet
            ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
            wrappedController = IWrappedEthRegistrarController(0xFED6a969AaA60E4961FCD3EBF1A2e8913ac65B72);
        } else {
            revert("Unsupported network");
        }
    }
}
