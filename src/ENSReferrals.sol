// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AxiomIncentives } from "@axiom-crypto/axiom-incentives/AxiomIncentives.sol";

contract ENSReferrals is AxiomIncentives {
    /// @dev The unique identifier of the registration circuit accepted by this contract.
    bytes32 public immutable REGISTRATION_QUERY_SCHEMA;

    /// @dev The unique identifier of the renewal circuit accepted by this contract.
    bytes32 public immutable RENEWAL_QUERY_SCHEMA;

    /// @notice Emitted when a claim for ENS registrations is made.
    /// @param referrerId The ID of the referrer.
    /// @param startClaimId The ID of the first claim in the claim batch.
    /// @param endClaimId The ID of the last claim in the claim batch.
    /// @param totalValue The total value of the claim batch.
    event ClaimRegistrations(uint16 indexed referrerId, uint256 startClaimId, uint256 endClaimId, uint256 totalValue);

    /// @notice Emitted when a claim for ENS renewals is made.
    /// @param referrerId The ID of the referrer.
    /// @param startClaimId The ID of the first claim in the claim batch.
    /// @param endClaimId The ID of the last claim in the claim batch.
    /// @param totalValue The total value of the claim batch.
    event ClaimRenewals(uint16 indexed referrerId, uint256 startClaimId, uint256 endClaimId, uint256 totalValue);

    /// @notice Construct a new ENSReferrals contract.
    /// @param  _axiomV2QueryAddress The address of the AxiomV2Query contract.
    /// @param  incentivesQuerySchemas A length-2 list containing the querySchema for registration and renewals.
    constructor(address _axiomV2QueryAddress, bytes32[] memory incentivesQuerySchemas)
        AxiomIncentives(_axiomV2QueryAddress, incentivesQuerySchemas)
    {
        require(incentivesQuerySchemas.length == 2, "Invalid incentivesQuerySchemas length");
        REGISTRATION_QUERY_SCHEMA = incentivesQuerySchemas[0];
        RENEWAL_QUERY_SCHEMA = incentivesQuerySchemas[1];
    }

    /// @inheritdoc AxiomIncentives
    function _validateClaim(
        bytes32, // querySchema
        address, // caller
        uint256, // startClaimId
        uint256, // endClaimId
        uint256 incentiveId,
        uint256 // totalValue
    ) internal pure override {
        uint16 referrerId = uint16(incentiveId);
        require(referrerId != 0, "Invalid referrer ID");
    }

    /// @inheritdoc AxiomIncentives
    function _sendClaimRewards(
        bytes32 querySchema,
        address, // caller
        uint256 startClaimId,
        uint256 endClaimId,
        uint256 incentiveId,
        uint256 totalValue
    ) internal override {
        uint16 referrerId = uint16(incentiveId);
        if (querySchema == REGISTRATION_QUERY_SCHEMA) {
            // TODO: Send funds to the referrer based on the referrerId
            emit ClaimRegistrations(referrerId, startClaimId, endClaimId, totalValue);
        } else if (querySchema == RENEWAL_QUERY_SCHEMA) {
            // TODO: Send funds to the referrer based on the referrerId
            emit ClaimRenewals(referrerId, startClaimId, endClaimId, totalValue);
        }
    }
}
