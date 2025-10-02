# ENS Referrals Smart Contracts

This repository contains smart contracts for tracking referral information during ENS domain renewals. Three different approaches are implemented to handle various use cases and tradeoffs.

## Contracts Overview

### 1. UniversalRegistrarRenewalWithReferrer

**Purpose**: Universal renewal contract that works with both wrapped and unwrapped .eth names
**Strategy**: Renews through unwrapped ETHRegistrarController (for referral tracking) then synchronizes with WrappedEthRegistrarController
**Gas Cost**: ~129k gas for `renew()`

- Works with all ENS name types (wrapped, unwrapped, legacy)
- Single contract solution for all renewal scenarios
- Emits single `NameRenewed` event via `UnwrappedEthRegistrarController` with renewal details and referral tracking
  - this is most straightforward for indexers

### 2. WrappedRegistrarRenewalWithReferral

**Purpose**: Dedicated renewal contract for wrapped .eth names with comprehensive referral tracking
**Strategy**: Calculates price, renews through WrappedEthRegistrarController, retrieves updated expiry, emits detailed event
**Gas Cost**: ~136k gas for `renew()`

- Optimized specifically for wrapped ENS names
- Emits additional `NameRenewed` event in `WrappedRegistrarRenewalWithReferral` with all renewal information in a single event
  - this is straightforward for indexers
- Higher gas cost due to additional price calculation and expiry retrieval operations

### 3. SimpleWrappedRegistrarRenewal

**Purpose**: Simplified renewal contract with minimal overhead
**Strategy**: Direct renewal call with basic referral event emission
**Gas Cost**: ~109k gas for `renew()`

- Lowest gas cost approach (~20% savings vs full implementation)
- Minimal event emission - only tracks referral relationship
  - More complex for indexers - requires correlating multiple events across the same transaction

## Architecture

All contracts implement the `IRegistrarRenewalWithReferral` interface and are `Ownable` for future Enscribe compatibility. They interact with:

- **IETHRegistrarController**: For unwrapped name renewals
- **IWrappedEthRegistrarController**: For wrapped name renewals
- **INameWrapper**: For wrapped name expiry data

## Gas Cost Comparison

| Contract | Gas Cost | Use Case |
|----------|----------|----------|
| SimpleWrappedRegistrarRenewal | ~109k | Gas-optimized, minimal tracking |
| UniversalRegistrarRenewalWithReferrer | ~129k | Universal compatibility |
| WrappedRegistrarRenewalWithReferral | ~136k | Comprehensive wrapped name tracking |

### Quick Start

```bash
forge install
forge test
```
