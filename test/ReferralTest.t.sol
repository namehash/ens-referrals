//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Test} from "forge-std/Test.sol";

import {ENS} from "ens-contracts/registry/ENS.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IETHRegistrarController} from "ens-contracts/ethregistrar/IETHRegistrarController.sol";
import {IBaseRegistrar} from "ens-contracts/ethregistrar/IBaseRegistrar.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {NameCoder} from "ens-contracts/utils/NameCoder.sol";

import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {UniversalRegistrarRenewalWithOriginalReferrerEvent} from "../src/UniversalRegistrarRenewalWithOriginalReferrerEvent.sol";
import {UniversalRegistrarRenewalWithAdditionalReferrerEvent} from "../src/UniversalRegistrarRenewalWithAdditionalReferrerEvent.sol";
import {UniversalRegistrarRenewalWithSimpleReferrerEvent} from "../src/UniversalRegistrarRenewalWithSimpleReferrerEvent.sol";
import {UniversalRegistrarRenewalWithReferrer} from "../src/UniversalRegistrarRenewalWithReferrer.sol";

contract ReferralsTest is Test {
    ENS constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper constant NAME_WRAPPER = INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    IWrappedEthRegistrarController constant WRAPPED_ETH_REGISTRAR_CONTROLLER =
        IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
    IETHRegistrarController constant UNWRAPPED_ETH_REGISTRAR_CONTROLLER =
        IETHRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547);
    IBaseRegistrar constant BASE_REGISTRAR = IBaseRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    // registered via LegacyEthRegistrarController
    string constant TEST_LEGACY_LABEL = "shrugs";

    // registered via WrappedEthRegistrarController
    string constant TEST_WRAPPED_LABEL = "scotttaylor";

    // registered via UnwrappedEthRegistrarController
    string constant TEST_UNWRAPPED_LABEL = "daonotes";

    uint256 constant TEST_DURATION = 365 days;

    // forge-lint: disable-next-line(mixed-case-variable)
    bytes32 REFERRER = keccak256("test-referrer"); // TODO: referrer formatting

    UniversalRegistrarRenewalWithOriginalReferrerEvent universalRenewal;
    UniversalRegistrarRenewalWithAdditionalReferrerEvent wrappedRenewal;
    UniversalRegistrarRenewalWithSimpleReferrerEvent simpleWrappedRenewal;
    UniversalRegistrarRenewalWithReferrer universalReferrerRenewal;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        universalRenewal = new UniversalRegistrarRenewalWithOriginalReferrerEvent(
            ENS_REGISTRY, WRAPPED_ETH_REGISTRAR_CONTROLLER, UNWRAPPED_ETH_REGISTRAR_CONTROLLER
        );

        wrappedRenewal =
            new UniversalRegistrarRenewalWithAdditionalReferrerEvent(ENS_REGISTRY, WRAPPED_ETH_REGISTRAR_CONTROLLER, NAME_WRAPPER);

        simpleWrappedRenewal = new UniversalRegistrarRenewalWithSimpleReferrerEvent(ENS_REGISTRY, WRAPPED_ETH_REGISTRAR_CONTROLLER);

        universalReferrerRenewal = new UniversalRegistrarRenewalWithReferrer(ENS_REGISTRY, WRAPPED_ETH_REGISTRAR_CONTROLLER);
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

        // Renew
        wrappedRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

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
        IPriceOracle.Price memory price = UNWRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_UNWRAPPED_LABEL, TEST_DURATION);

        // Renew
        universalRenewal.renew{value: price.base}(TEST_UNWRAPPED_LABEL, TEST_DURATION, REFERRER);

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
        IPriceOracle.Price memory price = UNWRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_LEGACY_LABEL, TEST_DURATION);

        // Renew
        universalRenewal.renew{value: price.base}(TEST_LEGACY_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");
    }

    function test_simpleRenewalWrappedName() public {
        bytes32 labelHash = keccak256(bytes(TEST_WRAPPED_LABEL));
        uint256 labelTokenId = uint256(labelHash);
        bytes32 node = NameCoder.namehash(NameCoder.encode(string.concat(TEST_WRAPPED_LABEL, ".eth")), 0);

        // assert is Wrapped
        assertEq(NAME_WRAPPER.isWrapped(node), true, "TEST_WRAPPED_LABEL is in NameWrapper");

        // Get initial expiry from BaseRegistrar
        uint256 initialExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithSimpleReferrerEvent.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER);

        // Renew
        simpleWrappedRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");
    }

    function test_universalReferrerRenewalWrappedName() public {
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

        // Expect RenewalReferred event
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew
        universalReferrerRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");

        // Assert NameWrapper data updated
        (,, uint64 newWrappedExpiry) = NAME_WRAPPER.getData(tokenId);
        assertEq(newWrappedExpiry, initialWrappedExpiry + TEST_DURATION, "NameWrapper expiry should be updated");
    }

    function test_universalReferrerRenewalRefundsExcess() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        uint256 excessAmount = 0.1 ether;
        uint256 totalValue = price.base + excessAmount;
        uint256 initialBalance = address(this).balance;

        // Renew with excess value
        universalReferrerRenewal.renew{value: totalValue}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Check that excess was refunded
        uint256 finalBalance = address(this).balance;
        assertEq(finalBalance, initialBalance - price.base, "Excess value should be refunded");
    }

    function test_universalReferrerRenewalEmitsCorrectEvent() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with correct parameters
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew
        universalReferrerRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_universalReferrerRenewalWithZeroReferrer() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with zero referrer
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, bytes32(0), price.base, TEST_DURATION);

        // Renew with zero referrer
        universalReferrerRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, bytes32(0));
    }

    function test_costEventAccuracyWithExactPayment() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with exact cost
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew with exact payment
        universalReferrerRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_costEventAccuracyWithOverpayment() public {
        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 overpayment = 0.05 ether;
        uint256 totalPayment = price.base + overpayment;

        // Expect RenewalReferred event with actual cost (not overpayment)
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew with overpayment
        universalReferrerRenewal.renew{value: totalPayment}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_costEventAccuracyWithPreExistingBalance() public {
        // Send some ETH to the contract before renewal
        uint256 preExistingBalance = 0.01 ether;
        payable(address(universalReferrerRenewal)).transfer(preExistingBalance);

        // Calculate renewal price
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);

        // Expect RenewalReferred event with correct cost (should not include pre-existing balance)
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew with exact payment
        universalReferrerRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    function test_costEventAccuracyWithPreExistingBalanceAndOverpayment() public {
        // Send some ETH to the contract before renewal
        uint256 preExistingBalance = 0.01 ether;
        payable(address(universalReferrerRenewal)).transfer(preExistingBalance);

        // Calculate renewal price and add overpayment
        IPriceOracle.Price memory price = WRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_WRAPPED_LABEL, TEST_DURATION);
        uint256 overpayment = 0.02 ether;
        uint256 totalPayment = price.base + overpayment;

        // Expect RenewalReferred event with correct cost (should not include pre-existing balance or overpayment)
        vm.expectEmit(true, true, true, true);
        emit UniversalRegistrarRenewalWithReferrer.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER, price.base, TEST_DURATION);

        // Renew with overpayment
        universalReferrerRenewal.renew{value: totalPayment}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);
    }

    receive() external payable {}
}
