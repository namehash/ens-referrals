# R&D Prototype Status

This prototype is under active R&D as we explore solutions for a [proposed ENS Referral Program](https://namehashlabs.org/ens-referral-program).

# ENS Referrals

The `ENSReferrals` contract allows **ENS referrers** to receive self-serve referral rewards for ENS `.eth` name registrations and renewals. The key features of the system are:

- **No changes** are required to the currently deployed ENS contracts or the ENS registration and renewal flows. In particular, the economics of registration and renewal are identical between referred and non-referred users.
- All referral claims are cryptographically verified on-chain by zero-knowledge proofs.

Referrers can use the [AxiomIncentives](https://github.com/axiom-crypto/axiom-incentives) system to prove with [Axiom](https://axiom.xyz)-provided ZK proofs that users they referred made `.eth` registrations or renewals recorded in `NameRenewed` and `NameRegistered` events from the `ETHRegistrarController` contract. They can then be rewarded on-chain in proportion to the base fees they have paid to ENS.

This work is the result of a collaboration between [Axiom](https://axiom.xyz/) and [NameHash Labs](https://namehashlabs.org/).

## Referral Mechanism

To implement referrals, we associate each referrer with a `uint16 referrerId` identifier. When referring a user, they can inject this `referrerId` into name registrations and renewals by:

- encoding it as `referrerId = duration % 86400` for a new `.eth` registration
- encoding it as `referrerId = expiry % 86400` for a `.eth` renewal

When processing user registrations and renewals, referrers should use `duration` and `expiry` parameters which encode the `referrerId` in this way in the standard ENS `.eth` registration and renewal contracts. This change in flow occurs purely offchain, and no additional changes to the `.eth` registration or renewal process are necessary.

For referrer claims, the `ENSReferrals` contract implements the [AxiomIncentives](https://github.com/axiom-crypto/axiom-incentives) system to allow referrers to prove in ZK that they sourced new registrations or renewals for the protocol. We handle registrations and renewals as follows:

- **Registrations:** Any name registration is eligible, but we exclude all premium fees in the computation of fees eligible for rewards. In particular, premium fees for 3- and 4-letter names and temporary premiums are excluded. Registrations are tracked via the `NameRegistered` events emitted by the `ETHRegistarController` contract. The total ETH-denominated base registration fees paid are summed over the proven registrations and sent to `ENSReferrals` in a callback.
- **Renewals:** Any renewal is eligible, but again we exclude all premium fees. Renewals are tracked via the `NameRenewed` events emitted by the `ETHRegistarController` contract. The total ETH-denominated base renewal fees paid are summed over the proven renewals and sent to `ENSReferrals` in a callback.

After receiving a ZK-verified reward amount, the `ENSReferrals` contract records the amount of reward to be remitted for each referrer. In a real implementation, the ENS DAO would need to approve an implementation that actually remits funds.

## Verifying the Referral Amount

To ensure that referral rewards are given for the correct registration and renewal fee amounts and that no double claims are allowed, referrers must prove their previous activity in ZK in order to claim a referral fee. To do so, they prove that `NameRegistered` or `NameRenewed` events corresponding to their `referralId` were part of the history of Ethereum. This is done using the Axiom system, which uses ZK to verify Merkle-Patricia trie proofs of the log events into the `receiptsRoot` of the corresponding block header. To learn more about how this process works and the security guarantees given by ZK, see the [Axiom ZK docs](https://docs.axiom.xyz/protocol/protocol-design/zk-circuits-for-axiom-queries).

To avoid double claims, each claimed renewal or registration is identified with a `uint256 claimId` which is a monotone increasing identifier for all Ethereum receipts. For each referrer claim, the ZK-proven results via Axiom that are provided to `ENSReferrals` via callback are:

- `uint256 startClaimId` -- the smallest `claimId` in the claimed batch
- `uint256 endClaimId` -- the largest `claimId` in the claimed batch
- `uint256 incentiveId` -- the `referrerId` for all claims in this batch
- `uint256 totalValue` -- the total value of ETH-denominated base registration or renewal fees in this batch.

Referral rewards can be distributed to the referrer in proportion to `totalValue`.

The [AxiomIncentives](https://github.com/axiom-crypto/axiom-incentives) system enforces that claims must be made in increasing order of `claimId`, which prevents any registration or renewal event from being claimed twice. In addition, we exclude `referrerId = 0`, which corresponds to the default behavior of the official ENS frontend.

## Testing

To verify that the system performs correctly, we perform unit testing and integration testing on:

- The `ENSReferrals` contract which accepts Axiom-proven verification of ENS registrations and renewals and ensures no double claims.
- The ZK circuits for registrations and renewals written using the [Axiom SDK](https://docs.axiom.xyz/sdk/rust-sdk/axiom-rust) which allow referrers to prove that they drove `.eth` registrations or renewals.

For `ENSReferrals`, we use Foundry tests with 100% test coverage based on the [axiom-std](https://github.com/axiom-crypto/axiom-std) library to check that:

- Valid referral claims for registrations are processed correctly.
- Valid referral claims for renewals are processed correctly.
- Referral claims which involve double claiming the same registration or renewal event are disallowed.

For the ZK circuits, we use Rust unit tests to check for both registrations and renewals that:

- The `referralId` is parsed correctly from the `duration` or `expiry` fields.
- The fee value for each referral excludes premium fees for 3- and 4-letter names and temporary premiums.
- The `claimId` computed for each event are correct.
- The total registration or renewal fee computations are correct.

## Development

To set up the development environment, run:

```
forge install
npm install   # or `yarn install` or `pnpm install`
```

## License

Licensed under the MIT License, Copyright © 2023-present [NameHash Labs](https://namehashlabs.org).

See [LICENSE](./LICENSE) for more information.
