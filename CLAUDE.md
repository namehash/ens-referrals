# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Foundry-based Solidity project for ENS referrals smart contracts. The project follows standard Foundry conventions with contracts in `src/`, tests in `test/`, and deployment scripts in `script/`.

## Core Commands

### Building and Testing
```bash
# Build all contracts
forge build

# Run all tests
forge test

# Run a specific test contract
forge test --match-contract CounterTest

# Run a specific test function
forge test --match-test test_Increment

# Run tests with gas reporting
forge test --gas-report

# Format Solidity code
forge fmt

# Generate gas snapshots
forge snapshot
```

### Development Tools
```bash
# Start local blockchain node
anvil

# Interactive Solidity REPL
chisel

# Get help for any command
forge --help
cast --help
anvil --help
```

### Deployment
```bash
# Deploy using a script (replace with actual script name)
forge script script/Counter.s.sol:CounterScript --rpc-url <rpc_url> --private-key <private_key>

# Verify contract on Etherscan
forge verify-contract <contract_address> <contract_name> --etherscan-api-key <api_key>
```

## Project Structure

- `src/` - Smart contracts
- `test/` - Test files (using forge-std Test framework)
- `script/` - Deployment and utility scripts
- `lib/` - External dependencies (managed via git submodules)
- `out/` - Build artifacts (generated)
- `foundry.toml` - Foundry configuration

## Testing Patterns

Tests inherit from `forge-std/Test.sol` and follow these conventions:
- `setUp()` function for test initialization
- `test_` prefix for standard tests
- `testFuzz_` prefix for fuzz tests
- Use `assertEq()`, `assertTrue()`, and other forge-std assertions
- `vm.` cheatcodes for advanced testing scenarios

## Dependencies

External libraries are managed as git submodules in the `lib/` directory. The project uses `forge-std` as the testing framework.

## Documentation

- [Foundry Book](https://book.getfoundry.sh/) - Complete Foundry documentation