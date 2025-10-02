# ENS Referrals Smart Contracts

This repository contains smart contracts for tracking referral information during .eth subdomain domain renewals. Three different approaches are implemented to illustrate various tradeoffs.

**All** of these contract implementations are able to renew _any_ direct .eth subname with included referrer information. They differ in their approaches to indexer ergonomics and gas costs, primarily. Integrating apps could _optionally_ check the wrapped status of a name and switch between a `UniversalRegistrarRenewal*.renew()` and `UnwrappedEthRegistrarController.renew()` to save users the gas cost difference on their renewal transaction.

For reference, `WrappedETHRegistrarController.renew()` costs ~88k gas.

## Contracts Overview

### 1. [UniversalRegistrarRenewalWithOriginalReferrerEvent](src/UniversalRegistrarRenewalWithOriginalReferrerEvent.sol)

**Strategy**: Renews through `UnwrappedEthRegistrarController` (for referral tracking using the original event) then synchronizes with `WrappedEthRegistrarController`
**Gas Cost**: ~129k gas for `renew()` (+41k gas @ 1 gwei @ $4500 ETH = +$0.18 per renew tx)

This is the most straightforward approach: the single source-of-truth `NameRenewed` event on the `UnwrappedEthRegistrarController` is very ergonomic to index, and the additional cost-per-call is only +41k gas (+$0.18 at current pricing).

### 2. [UniversalRegistrarRenewalWithAdditionalReferrerEvent](src/UniversalRegistrarRenewalWithAdditionalReferrerEvent.sol)

**Strategy**: Calculates price, renews through `WrappedEthRegistrarController`, retrieves updated expiry, emits `NameRenewed`
**Gas Cost**: ~136k gas for `renew()` (+48k gas @ 1 gwei @ $4500 ETH = +$0.22 per renew tx)

This approach emits the same `UnwrappedEthRegistrarController#NameRenewed()` event without calling `UnwrappedEthRegistrarController` but the gas required to (re)calculate the price makes it cost more than `UniversalRegistrarRenewalWithOriginalReferrerEvent.renew()`.

### 3. [UniversalRegistrarRenewalWithSimpleReferrerEvent](src/UniversalRegistrarRenewalWithSimpleReferrerEvent.sol)

**Strategy**: Direct renewal call with basic referral event emission
**Gas Cost**: ~109k gas for `renew()` (+21k gas @ 1 gwei @ $4500 ETH = +$0.09 per renew tx)

If gas is a primary concern, we can save $0.13 per call by emitting a simpler `RenewalReferred` event in the wrapper contract and requiring that indexers do some extra work on their end to reconstitute the correct state (i.e. by correlating the simpler `RenewalReferred` event with the `WrappedEthRegistrarController#NameRenewed()` event emitted in the same transaction). This approach sacrifices indexer ergonomics to save 20k gas.

## Architecture

All contracts implement the `IRegistrarRenewalWithReferral` interface and are `Ownable` for future contract naming compatibility.

```solidity
//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IRegistrarRenewalWithReferral {
    function renew(string calldata label, uint256 duration, bytes32 referrer) external payable;
}
```

## Gas Cost Comparison

| Contract | Gas Cost |
|----------|----------|
| UniversalRegistrarRenewalWithSimpleReferrerEvent | ~109k |
| UniversalRegistrarRenewalWithOriginalReferrerEvent | ~129k |
| UniversalRegistrarRenewalWithAdditionalReferrerEvent | ~136k |

### Quick Start

```bash
forge install
forge test
```
