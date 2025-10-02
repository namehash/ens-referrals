//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Test} from "forge-std/Test.sol";

import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IETHRegistrarController} from "ens-contracts/ethregistrar/IETHRegistrarController.sol";
import {IBaseRegistrar} from "ens-contracts/ethregistrar/IBaseRegistrar.sol";
import {IPriceOracle} from "ens-contracts/ethregistrar/IPriceOracle.sol";
import {NameCoder} from "ens-contracts/utils/NameCoder.sol";

import {IWrappedEthRegistrarController} from "../src/IWrappedEthRegistrarController.sol";
import {UniversalRegistrarRenewalWithReferrer} from "../src/UniversalRegistrarRenewalWithReferrer.sol";
import {WrappedRegistrarRenewalWithReferral} from "../src/WrappedRegistrarRenewalWithReferral.sol";
import {SimpleWrappedRegistrarRenewal} from "../src/SimpleWrappedRegistrarRenewal.sol";

contract ReferralsTest is Test {
    INameWrapper constant NAME_WRAPPER = INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    IWrappedEthRegistrarController constant WRAPPED_ETH_REGISTRAR_CONTROLLER =
        IWrappedEthRegistrarController(0x253553366Da8546fC250F225fe3d25d0C782303b);
    IETHRegistrarController constant UNWRAPPED_ETH_REGISTRAR_CONTROLLER =
        IETHRegistrarController(0x59E16fcCd424Cc24e280Be16E11Bcd56fb0CE547);
    IBaseRegistrar constant BASE_REGISTRAR = IBaseRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    string constant TEST_WRAPPED_LABEL = "scotttaylor";
    string constant TEST_UNWRAPPED_LABEL = "daonotes";
    string constant TEST_LEGACY_LABEL = "shrugs";
    uint256 constant TEST_DURATION = 365 days;
    bytes32 REFERRER = keccak256("test-referrer"); // TODO: referrer formatting

    UniversalRegistrarRenewalWithReferrer universalRenewal;
    WrappedRegistrarRenewalWithReferral wrappedRenewal;
    SimpleWrappedRegistrarRenewal simpleWrappedRenewal;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        universalRenewal = new UniversalRegistrarRenewalWithReferrer(
            WRAPPED_ETH_REGISTRAR_CONTROLLER, UNWRAPPED_ETH_REGISTRAR_CONTROLLER
        );

        wrappedRenewal = new WrappedRegistrarRenewalWithReferral(WRAPPED_ETH_REGISTRAR_CONTROLLER, NAME_WRAPPER);

        simpleWrappedRenewal = new SimpleWrappedRegistrarRenewal(WRAPPED_ETH_REGISTRAR_CONTROLLER);
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
        IPriceOracle.Price memory price =
            UNWRAPPED_ETH_REGISTRAR_CONTROLLER.rentPrice(TEST_UNWRAPPED_LABEL, TEST_DURATION);

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
        emit SimpleWrappedRegistrarRenewal.RenewalReferred(TEST_WRAPPED_LABEL, REFERRER);

        // Renew
        simpleWrappedRenewal.renew{value: price.base}(TEST_WRAPPED_LABEL, TEST_DURATION, REFERRER);

        // Assert BaseRegistrar expiry updated
        uint256 newExpiry = BASE_REGISTRAR.nameExpires(labelTokenId);
        assertEq(newExpiry, initialExpiry + TEST_DURATION, "BaseRegistrar expiry should be updated");
    }

    receive() external payable {}
}
