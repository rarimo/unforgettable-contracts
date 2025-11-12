# Unforgettable Contracts

### Overview

Unforgettable Contracts is a set of Solidity smart contracts designed for smart account or vault access recovery 
on top of the [EIP-7947](https://eips.ethereum.org/EIPS/eip-7947).

It provides mechanisms for managing different recovery methods with subscription-based access, including crosschain 
subscription synchronization via Wormhole.

### Contracts

```ml
contracts
├── accounts
│   ├── Account — "Minimal Solady EIP-7702 smart account integrating the recovery"
│   ├── AccountSubscriptionManager — "Smart account-specific subscription manager"
│   └── Base7702AccountRecovery — "Basic recovery logic implementation for an EIP-7702 account"
├── core
│   ├── strategies
│   │   ├── ARecoveryStrategy — "Abstract recovery strategy implementation"
│   │   └── SignatureRecoveryStrategy — "Recovery strategy logic based on the EIP-712 signature"
│   ├── subscription
│   │   ├── modules
│   │   │   ├── BaseSubscriptionModule — "Basic subscription extension logic"
│   │   │   ├── CrossChainModule — "Crosschain subscription synchronization module"
│   │   │   ├── SBTDiscountModule — "Subscription discounts based on ownership of supported SBTs"
│   │   │   ├── SBTPaymentModule — "Subscription payments using SBTs mapped to fixed durations"
│   │   │   ├── SignatureSubscriptionModule — "Subscription extension using signed EIP-712 permits"
│   │   │   └── TokensPaymentModule — "Subscription payments in ETH or ERC-20 tokens"
│   │   ├── BaseSideChainSubscriptionManager — "Base subscription manager for side chains"
│   │   └── BaseSubscriptionManager — "Subscription manager coordinating multiple payment modules"
│   └── RecoveryManager — "Central recovery coordinator with pluggable strategies"
├── crosschain
│   ├── SideChainSubscriptionManager — "Subscription manager for side chains with crosschain sync support"
│   ├── SubscriptionsStateReceiver — "Receives and processes crosschain subscription state updates"
│   └── SubscriptionsSynchronizer — "Synchronizes subscription states across chains via Wormhole"
├── helper-data
│   ├── HelperDataFactory — "Factory managing account registration, helper data parts submission, and metadata/subscription tracking"
|   └── HelperDataRegistry — "Helper data storage updated via EIP-712 signatures"
├── libs
│   ├── EIP712SignatureChecker — "A wrapper around OZ SignatureChecker for EIP-712 signature validations"
│   └── TokensHelper — "ETH/ERC-20 transfer utilities"
├── safe
│   └── UnforgettableRecoveryModule — "Gnosis Safe module enabling access recovery by swapping a specified owner"
├── tokens
│   └── ReservedRMO — "ERC-20 token granting each vault a one-time reserved token allocation"
└── vaults
    ├── Vault — "A vault controlled with a master key EIP-712 signature"
    ├── VaultFactory — "Deterministic CREATE2 factory for Vaults with support for a registry of unchangeable vault names"
    └── VaultSubscriptionManager — "Vault-specific subscription manager"
```

### Vaults deployment

To ensure that user vaults will always deploy at the same addresses with the same masterKey across different chains, we use the `CREATE3` approach via [CreateX](https://github.com/pcaversaccio/createx) to deploy the `VaultFactory` contract.

| Contract Name            | Address                                      | Chain             |
| ------------------------ | -------------------------------------------- | ----------------- |
| VaultFactory             | `0x54C239E71af51Fc141A2BDf5469dc992b7256AD8` | Ethereum Mainnet  |
| VaultSubscriptionManager | `0xdc8838478f49C212e68fD8b538B90c81D0f47621` | Ethereum Mainnet  |

> [!NOTE]
> The `VaultFactory` address will be the same on every supported chain, but other contract addresses may differ.

> [!IMPORTANT]
> We used the salt `0x00D37f35Ec44ecC4e2F54de1FA3208F73d632E5900004e6f6e204f626c697461` during deployment. This ensures that only the protocol address `0x00D37f35Ec44ecC4e2F54de1FA3208F73d632E59` can deploy the VaultFactory contract across all chains.

### Setup

This project uses both Hardhat and Foundry. Follow these steps to set up the repository:

#### Prerequisites

1. **Install Node.js** (v18 or later)
2. **Install Foundry**:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

#### Installation

Install all required dependencies:

```bash
npm install
```

Initialize Foundry submodules:

```bash
git submodule update --init --recursive
```

### Usage

#### Compilation

To compile contracts using Hardhat:

```bash
npm run compile
```

To compile contracts using Foundry:

```bash
forge build
```

#### Testing

To run the tests, execute the following command:

```bash
npm run test
```

#### Local deployment

To deploy the contracts locally, run the following commands (in the different terminals):

```bash
npm run private-network
npm run deploy-localhost
```
