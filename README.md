# ENS Holiday Awards

## Developer Implementation Guide

# ENS Referrals Smart Contract

A contract for renewing any direct .eth subname with referral tracking.

## Overview

This project provides `UniversalRegistrarRenewalWithReferrer`, a contract that enables direct .eth subname renewals with referral tracking. The contract wraps the standard `WrappedEthRegistrarController.renew()` function to add referral event emission and accurate cost tracking, ensuring that any NameWrapper-wrapped names also have their expiry synchronized with the `BaseRegistrar`.

It balances implementation clarity, user gas cost, and indexer logic based on exploration with the ENS Labs team. It emits a `RenewalReferred` event with the following ABI:

```solidity
/// @notice Emitted when a name is renewed with a referrer.
///
/// @param label The .eth subname label
/// @param labelHash The keccak256 hash of the .eth subname label
/// @param cost The actual cost of the renewal
/// @param duration The duration of the renewal
/// @param referrer The referrer of the renewal
event RenewalReferred(
    string label,
    bytes32 indexed labelHash,
    uint256 cost,
    uint256 duration,
    bytes32 referrer
);
```

Note that we use `duration` over `expiry` (as found in `UnwrappedEthRegistrarController#NameRenewed()`) to avoid the gas costs of an additional read.

The `UniversalRegistrarRenewalWithReferrer.renew()` method has an identical ABI to `UnwrappedEthRegistrarController.renew()`: integrating applications need only send renewal transactions to `UniversalRegistrarRenewalWithReferrer` instead of `UnwrappedEthRegistrarController` to ensure that renewals of _all_ direct .eth subnames include referral tracking.

```solidity
function renew(string calldata label, uint256 duration, bytes32 referrer) external payable
```

### Setup

```bash
forge install
forge build
```

Copy `.env.example` to `.env` and configure your environment variables:

```bash
cp .env.example .env
# Edit .env with your values
```

Required environment variables:
- `MAINNET_RPC_URL`: RPC endpoint for mainnet (tests use mainnet fork)
- `PRIVATE_KEY`: Private key for deployment (optional, for deployment only)

```bash
# Run tests (requires MAINNET_RPC_URL)
forge test
```

## Deployment

Deploy to mainnet or Sepolia:

```bash
# Deploy to mainnet
forge script script/Deploy.s.sol --rpc-url mainnet -vvvv --interactives 1 --broadcast --verify

# Deploy to sepolia
forge script script/Deploy.s.sol --rpc-url sepolia -vvvv --interactives 1 --broadcast --verify
```

The script automatically detects the network and uses the appropriate ENS and controller addresses.

## Existing Deployments

| Chain            | Address |
|------------------|---------|
| Ethereum Mainnet | [0xf55575Bde5953ee4272d5CE7cdD924c74d8fA81A](https://etherscan.io/address/0xf55575Bde5953ee4272d5CE7cdD924c74d8fA81A#code) |
| Ethereum Sepolia | [0x7AB2947592C280542e680Ba8f08A589009da8644](https://sepolia.etherscan.io/address/0x7AB2947592C280542e680Ba8f08A589009da8644#code) |