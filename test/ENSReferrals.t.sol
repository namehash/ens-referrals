// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

import "@axiom-crypto/axiom-std/AxiomTest.sol";

import { ENSReferrals } from "../src/ENSReferrals.sol";

contract ENSReferralsTest is AxiomTest {
    using Axiom for Query;

    ENSReferrals public referrals;

    struct AxiomInput {
        uint64[] blockNumbers;
        uint64[] txIdxs;
        uint64[] logIdxs;
        uint64 numClaims;
    }

    AxiomInput public registrationInput;
    AxiomInput public renewalInput;
    bytes32 public registrationQuerySchema;
    bytes32 public renewalQuerySchema;

    uint64 constant NUM_CLAIMS_REGISTRATIONS = 10;
    uint64 constant NUM_CLAIMS_RENEWALS = 9;

    event Claim(uint16 indexed referrerId, uint256 startClaimId, uint256 endClaimId, uint256 totalTradeVolume);

    function setUp() public {
        _createSelectForkAndSetupAxiom("sepolia", 5_329_575);

        uint64[] memory blockNumbersRegistration = new uint64[](NUM_CLAIMS_REGISTRATIONS);
        for (uint256 i = 0; i < NUM_CLAIMS_REGISTRATIONS; i++) {
            blockNumbersRegistration[i] = 5_329_565;
        }
        uint64[] memory txIdxsRegistration = new uint64[](NUM_CLAIMS_REGISTRATIONS);
        for (uint256 i = 0; i < NUM_CLAIMS_REGISTRATIONS; i++) {
            txIdxsRegistration[i] = 60;
        }
        uint64[] memory logIdxsRegistration = new uint64[](NUM_CLAIMS_REGISTRATIONS);
        for (uint256 i = 0; i < NUM_CLAIMS_REGISTRATIONS; i++) {
            logIdxsRegistration[i] = 6;
        }
        registrationInput = AxiomInput({
            blockNumbers: blockNumbersRegistration,
            txIdxs: txIdxsRegistration,
            logIdxs: logIdxsRegistration,
            numClaims: 1
        });

        uint64[] memory blockNumbersRenewal = new uint64[](NUM_CLAIMS_RENEWALS);
        for (uint256 i = 0; i < NUM_CLAIMS_RENEWALS; i++) {
            blockNumbersRenewal[i] = 5_203_518;
        }
        uint64[] memory txIdxsRenewal = new uint64[](NUM_CLAIMS_RENEWALS);
        for (uint256 i = 0; i < NUM_CLAIMS_RENEWALS; i++) {
            txIdxsRenewal[i] = 112;
        }
        uint64[] memory logIdxsRenewal = new uint64[](NUM_CLAIMS_RENEWALS);
        for (uint256 i = 0; i < NUM_CLAIMS_RENEWALS; i++) {
            logIdxsRenewal[i] = 1;
        }
        renewalInput = AxiomInput({
            blockNumbers: blockNumbersRenewal,
            txIdxs: txIdxsRenewal,
            logIdxs: logIdxsRenewal,
            numClaims: 1
        });

        bytes32[] memory querySchemas = new bytes32[](2);
        registrationQuerySchema = axiomVm.readCircuit("app/axiom/registration.circuit.ts", "aaaa");
        renewalQuerySchema = axiomVm.readCircuit("app/axiom/renewal.circuit.ts", "bbbb");
        querySchemas[0] = registrationQuerySchema;
        querySchemas[1] = renewalQuerySchema;
        referrals = new ENSReferrals(axiomV2QueryAddress, querySchemas);
    }

    function test_proveRegistration() public {
        Query memory q = query(registrationQuerySchema, abi.encode(registrationInput), address(referrals));
        q.send();

        bytes32[] memory results = q.prankFulfill();
        require(
            referrals.lastClaimedId(registrationQuerySchema, uint16(uint160(uint256(results[2]))))
                == uint256(results[1]),
            "Last claim ID not updated"
        );
    }

    function test_proveRenewal() public {
        Query memory q = query(renewalQuerySchema, abi.encode(renewalInput), address(referrals));
        q.send();

        bytes32[] memory results = q.prankFulfill();
        require(
            referrals.lastClaimedId(renewalQuerySchema, uint16(uint160(uint256(results[2])))) == uint256(results[1]),
            "Last claim ID not updated"
        );
    }

    function test_cantDoubleClaim() public {
        Query memory q = query(renewalQuerySchema, abi.encode(renewalInput), address(referrals));
        q.send();

        bytes32[] memory results = q.prankFulfill();
        require(
            referrals.lastClaimedId(renewalQuerySchema, uint16(uint160(uint256(results[2])))) == uint256(results[1]),
            "Last claim ID not updated"
        );

        FulfillCallbackArgs memory args = axiomVm.fulfillCallbackArgs(
            q.querySchema, q.input, q.callbackTarget, q.callbackExtraData, q.feeData, msg.sender
        );
        vm.prank(axiomV2QueryAddress);
        vm.expectRevert();
        IAxiomV2Client(args.callbackTarget).axiomV2Callback{ gas: args.gasLimit }(
            args.sourceChainId, args.caller, args.querySchema, args.queryId, args.axiomResults, args.callbackExtraData
        );
    }
}
