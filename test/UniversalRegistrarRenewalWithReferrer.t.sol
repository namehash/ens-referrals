//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Test} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";

import {ENS} from "ens-contracts/registry/ENS.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IBaseRegistrar} from "ens-contracts/ethregistrar/IBaseRegistrar.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {NameCoder} from "ens-contracts/utils/NameCoder.sol";

import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {UniversalRegistrarRenewalWithReferrer} from "../src/UniversalRegistrarRenewalWithReferrer.sol";

contract ReferralsTest is Test {
    ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper constant NAME_WRAPPER = INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    IWrappedEthRegistrarController constant WRAPPED_ETH_REGISTRAR_CONTROLLER =
        IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
    IBaseRegistrar constant BASE_REGISTRAR = IBaseRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    string constant TEST_LEGACY_LABEL = "shrugs"; // registered via LegacyEthRegistrarController
    string constant TEST_WRAPPED_LABEL = "scotttaylor"; // registered via WrappedEthRegistrarController
    string constant TEST_UNWRAPPED_LABEL = "daonotes"; // registered via UnwrappedEthRegistrarController

    uint256 constant TEST_DURATION = 365 days;

    // forge-lint: disable-next-line(mixed-case-variable)
    bytes32 REFERRER = keccak256("test-referrer"); // TODO: referrer formatting

    address renewer = vm.addr(1239586324895);
    UniversalRegistrarRenewalWithReferrer renewalContract;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        renewalContract = new UniversalRegistrarRenewalWithReferrer(ENS_REGISTRY, WRAPPED_ETH_REGISTRAR_CONTROLLER);

        // set renewalContract's balance to 0 because this address on mainnet has a balance
        vm.deal(address(renewalContract), 0);
        assertEq(address(renewalContract).balance, 0, "Must start with 0 excess balance");

        vm.deal(renewer, 10 ether);
        assertEq(renewer.balance, 10 ether, "Must start with dealt balance");

        vm.startPrank(renewer);
    }

    function test_renewWrappedName() public {
        bytes32 labelHash = keccak256(bytes(TEST_WRAPPED_LABEL));
        uint256 labelTokenId = uint256(labelHash);
        bytes32 node = NameCoder.namehash(NameCoder.encode(string.concat(TEST_WRAPPED_LABEL, ".eth")), 0);
        uint256 tokenId = uint256(node);

        // assert is Wrapped
        assertEq(NAME_WRAPPER.isWrapped(node), true, "TEST_WRAPPED_LABEL is in NameWrapper");

        // Get initial expiry from BaseRegistrar
        uint256 initialExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);

        // Get initial wrapped name data
        (,, uint64 initialWrappedExpiry) = NAME_WRAPPER.getData(tokenId);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 overpayment = 0.05 ether;

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, labelHash, price.base, TEST_DURATION, REFERRER);

        // Expect Refund
        vm.expectCall(address(renewer), overpayment, "");

        // Renew
        renewalContract.renew{value: price.base + overpayment}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");

        // Assert NameWrapper data updated
        (,, uint64 newWrappedExpiry) = NAME_WRAPPER.getData(tokenId);
        assertEq(newWrappedExpiry, initialWrappedExpiry + TEST_DURATION, "NameWrapper expiry should be updated");
    }

    function test_renewUnwrappedName() public {
        bytes32 labelHash = keccak256(bytes(TEST_UNWRAPPED_LABEL));
        uint256 labelTokenId = uint256(labelHash);

        // Get initial expiry from BaseRegistrar
        uint256 initialExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 overpayment = 0.05 ether;

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_UNWRAPPED_LABEL, labelHash, price.base, TEST_DURATION, REFERRER);

        // Expect Refund
        vm.expectCall(address(renewer), overpayment, "");

        // Renew
        renewalContract.renew{value: price.base + overpayment}(TEST_UNWRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");
    }

    function test_renewLegacyName() public {
        bytes32 labelHash = keccak256(bytes(TEST_LEGACY_LABEL));
        uint256 labelTokenId = uint256(labelHash);

        // Get initial expiry from BaseRegistrar
        uint256 initialExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_LEGACY_LABEL, TEST_DURATION);
        uint256 overpayment = 0.05 ether;

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_LEGACY_LABEL, labelHash, price.base, TEST_DURATION, REFERRER);

        // Expect Refund
        vm.expectCall(address(renewer), overpayment, "");

        // Renew
        renewalContract.renew{value: price.base + overpayment}(TEST_LEGACY_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");
    }

    function test_renewalWithZeroReferrer() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with zero referrer
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(
            TEST_WRAPPED_LABEL, keccak256(bytes(TEST_WRAPPED_LABEL)), price.base, TEST_DURATION, bytes32(0)
        );

        // Expect No Refund
        vm.expectCall(address(renewer), 0, "", 0);

        // Renew
        renewalContract.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, bytes32(0));
    }

    function test_exactPayment() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(
            TEST_WRAPPED_LABEL, keccak256(bytes(TEST_WRAPPED_LABEL)), price.base, TEST_DURATION, REFERRER
        );

        // Expect No Refund
        vm.expectCall(address(renewer), 0, "", 0);

        // Renew
        renewalContract.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_excessBalance() public {
        // Send some ETH to the contract before renewal
        uint256 excessBalance = 0.01 ether;
        payable(address(renewalContract)).transfer(excessBalance);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with correct cost (should not include pre-existing balance)
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(
            TEST_WRAPPED_LABEL, keccak256(bytes(TEST_WRAPPED_LABEL)), price.base, TEST_DURATION, REFERRER
        );

        // Expect Refund
        vm.expectCall(address(renewer), excessBalance, "");

        // Renew
        renewalContract.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_costEventAccuracyWithPreExistingBalanceAndOverpayment() public {
        // Send some ETH to the contract before renewal
        uint256 excessBalance = 0.01 ether;
        payable(address(renewalContract)).transfer(excessBalance);
        assertEq(address(renewalContract).balance, excessBalance, "Must have recieved excess");

        // Calculate renewal price and add overpayment
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 overpayment = 0.02 ether;

        // Expect RenewalReferred event with correct cost (should not include pre-existing balance or overpayment)
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(
            TEST_WRAPPED_LABEL, keccak256(bytes(TEST_WRAPPED_LABEL)), price.base, TEST_DURATION, REFERRER
        );

        // Expect Refund
        vm.expectCall(address(renewer), excessBalance + overpayment, "");

        // Renew
        renewalContract.renew{value: price.base + overpayment}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }
}
