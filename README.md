# ENS Referral Program

[ENS Referral Program](https://ensawards.org/ens-referral-program) is an incentive framework designed to distribute awards for referred .eth name registrations and renewals. It is currently being rolled out as a series of time-limited editions, with the long-term goal of refining its rules and mechanisms before launching a continuous, indefinite program.

So far, we have launched the `ENS Holiday Awards` edition (see details [here](https://ensawards.org/ens-referral-program/editions/2025-12/rules)) and are preparing more refined editions for `April 2026` and `May 2026`. Additional details will be announced soon.

These efforts are part of our SPP2 deliverables to the ENS DAO, which include our commitment to ultimately fund $50,000 USD in ENS Referral Program awards throughout the duration of SPP2.

## Developer Integration Guide

Developers can participate in any ENS Referral Program edition through referral hyperlinks or through onchain referrals at the smart-contract level.

### Referral Hyperlinks

Simply integrate referral links into your apps and websites. For example: Consider notifying your users of the .eth names they own and that will expire soon if not renewed.

[Generate your ENS Referral Program Link](https://ensawards.org/ens-referral-awards)

### Onchain Referrals

Integrate directly with ENS smart contracts for full flexibility and control over the user journey. Build the ultimate .eth name registration and renewal features directly into your app or wallet.

Onchain referrals for the registration / renewal of a direct subname of ".eth" should be implemented using the following contracts within the duration of any ENS Referral Program edition:

#### UnwrappedEthRegistrarController

* Supports referred registrations and renewals.
* [Mainnet deployment](https://etherscan.io/address/0x59e16fccd424cc24e280be16e11bcd56fb0ce547)
* [Sepolia deployment](https://sepolia.etherscan.io/address/0xfb3ce5d01e0f33f41dbb39035db9745962f1f968) (useful for testing, but no ENS Referral Program award distributions will be made on Sepolia)

#### UniversalRegistrarRenewalWithReferrer

* Supports referred renewals.
* In theory both referred registrations and referred renewals could all be made through the UnwrappedEthRegistrarController contract, but unfortunately there's a bug in this registrar controller where if a wrapped name is renewed through it, the expiration date of that name becomes out of sync between the "BaseRegistrar" and the "NameWrapper".
* To avoid this sync issue, we created the UniversalRegistrarRenewalWithReferrer contract in coordination with the ENS Labs team to ensure the correct thing always happens when renewing a .eth name, no matter if it is wrapped or not.
* See full details of this contract below in the full "UniversalRegistrarRenewalWithReferrer" section of this README.md file below.
* [Mainnet deployment](https://etherscan.io/address/0xf55575Bde5953ee4272d5CE7cdD924c74d8fA81A)
* [Sepolia deployment](https://sepolia.etherscan.io/address/0x7AB2947592C280542e680Ba8f08A589009da8644) (useful for testing, but no ENS Referral Program award distributions will be made on Sepolia)

#### "referrer" parameter values

The "referrer" parameter passed to the register / renew calls on the above contracts is a 32-byte value, while an Ethereum address is a 20-byte value. Therefore, to qualify for this program, the "referrer" parameter must match the following format:
* First 12-bytes: all zeros.
* Last 20-bytes: Ethereum mainnet address identifying the Referrer and where any Award Distributions the Referrer may earn will be deposited.
* Related utility functions for encoding / decoding referrer address values for use onchain can be found [here](https://github.com/namehash/ensnode/tree/main/packages/ens-referrals/src/v1).

### ENS Referral Program Rule Implementation

Logic implementing the `ENS Referral Program Rules` (all editions) is fully open source and can be found [here](https://github.com/namehash/ensnode/tree/main/packages/ens-referrals/src/v1).

### ENS Referral Program APIs

[ENSNode](https://ensnode.io/) v1.1.0+ offers APIs for querying ENS Referral Program leaderboards, referral metrics for specific referrers, and overall editions information. The easiest way to query these APIs is through the ENSNode client library as seen [here](https://github.com/namehash/ensnode/tree/main/packages/ens-referrals/src/v1). For more information [read the client docs](https://github.com/namehash/ensnode/blob/main/packages/ens-referrals/README.md).

# UniversalRegistrarRenewalWithReferrer

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
