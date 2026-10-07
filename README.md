![Mibboverse](docs/images/main_header.png)

# Mibboverse onchain contracts

[**Project documentation**](https://mibboverse.gitbook.io/mibboverse-docs)

Mibboverse is a platform for creating, operating, and monetizing AI agents. This repository contains the contracts that connect an agent's ERC-8004 identity to its creator and sell access through non-transferable passes.

The architecture separates identity custody, creator permissions, and access accounting. AI execution, metadata hosting, and request pricing happen outside these contracts; ownership and pass state are enforced onchain.

## Mainnet deployments

Mibboverse core contracts are deployed on **Robinhood Chain**.

### Robinhood Chain mainnet

Network: **Robinhood Chain mainnet**, chain ID **4663**.

| Contract | Address |
|---|---|
| MibboRegistry | [0x9C8c3C0Aa722E2A8F86c3d8007a0c51bd91B7E6e](https://robin.etherscan.io/address/0x9C8c3C0Aa722E2A8F86c3d8007a0c51bd91B7E6e) |
| MibboTreasury | [0x2CFB8b705642fCC21d139988Acdcecb35C613647](https://robin.etherscan.io/address/0x2CFB8b705642fCC21d139988Acdcecb35C613647) |
| MibboPass | [0x6174672f6C4a10365D1Ff1B61898C5b9cE8BA575](https://robin.etherscan.io/address/0x6174672f6C4a10365D1Ff1B61898C5b9cE8BA575) |
| ERC-8004 Identity Registry — external dependency | [0x8004A169FB4a3325136EB29fA0ceB6D2e539a432](https://robin.etherscan.io/address/0x8004A169FB4a3325136EB29fA0ceB6D2e539a432) |

## Architecture and agent creation flow

![Agent registration flow: User, Registry, ERC-8004, and Treasury](docs/images/register_flow.png)

The diagram shows the atomic agent-registration transaction. Registry creates the ERC-8004 identity, transfers its NFT to Treasury, and asks Treasury to set the agent wallet. Registry then records the creator as beneficial owner and emits `AgentRegistered`. Pass configuration is a separate call made after registration; it can be included in the same wallet batch when supported.

| Contract | Responsibility | Authority |
|---|---|---|
| [MibboRegistry](contracts/MibboRegistry.sol) | Registers ERC-8004 identities and records their beneficial owners. Authorizes metadata and URI updates. | No global administrator; updates require the recorded agent owner. |
| [MibboTreasury](contracts/MibboTreasury.sol) | Holds identity NFTs and performs privileged ERC-8004 writes for Registry. | Only the configured Registry can invoke those writes. Treasury ownership is renounced after configuration. |
| [MibboPass](contracts/MibboPass.sol) | Sells soulbound ERC-1155 passes and tracks expiry, configuration version, and request consumption. | Agent owners configure their passes; the contract owner manages usage relayers. |

## Agent identity and ownership

An agent has three distinct onchain references:

- **Identity NFT owner:** MibboTreasury, which retains the ERC-8004 NFT.
- **Beneficial owner:** the creator recorded by MibboRegistry, authorized to manage metadata and pass terms and receive subscription fees.
- **Agent wallet:** the wallet stored in the external ERC-8004 registry. Registration sets it to the caller using ERC-8004's signature and deadline checks.

`registerAgent(card, walletDeadline, walletSig)` performs one atomic flow:

1. Register `card.endpoint` in the external ERC-8004 Identity Registry and receive an `agentId`.
2. Transfer that identity NFT from Registry to Treasury.
3. Have Treasury confirm custody and call ERC-8004 `setAgentWallet` with the caller's wallet and supplied authorization.
4. Record the caller as beneficial owner and emit `AgentRegistered`.

If any step fails, the transaction reverts. Although `AgentCard` includes descriptive fields, this Registry implementation uses only `endpoint` during registration. Descriptions, artwork, and other document content belong in the referenced metadata; the contract does not store every card field.

The creator can subsequently call `updateAgentMetadata` and `updateAgentURI`. Registry checks beneficial ownership before forwarding the write through Treasury. The current contracts expose no beneficial-owner transfer or identity-NFT withdrawal function.

## Access passes

Each pass is an ERC-1155 token with **token ID equal to `agentId`**. Transfers between wallets revert; minting and replacement on purchase remain supported.

The agent owner calls `setConfig` to create a version containing:

| Field | Meaning |
|---|---|
| `tokenAddress` | ERC-20 used to pay for access. |
| `subscriptionFee` | Non-zero price in that token's smallest units. |
| `duration` | Access duration, between 1 and 365 days. |
| `maxRequests` | Non-zero request allowance. |
| `paused` | Whether access and purchases are paused. |
| `metadataURI` | Metadata URI stored for this configuration version. |

After approving the configured ERC-20, a buyer calls `purchasePass(agentId)`. The contract sends the full subscription fee directly to the beneficial owner, mints one pass, and stores the buyer's expiry, request limit, and purchased configuration version. Repurchasing replaces the previous pass and resets these values rather than extending or accumulating them.

`hasAccess(user, agentId)` requires a held pass, an unexpired timestamp, unused request quota, and an unpaused **current** agent configuration. A new configuration does not replace existing purchasers' expiry or quota. Pausing the current configuration blocks access for every holder of that agent's pass.

Authorized relayers report offchain consumption using `recordUsage` or `batchRecordUsage`. Usage is capped at the purchased request limit; reaching it disables access. A batch reverts as a whole if any item fails. The contract trusts relayers to report actual consumption—it does not execute or measure AI requests itself.

`uri(agentId)` returns the latest configuration's metadata URI; `getConfigURI(agentId, version)` returns a historical URI. `getPassStatus` exposes a buyer's state. `holderCount` counts wallets holding the token, including expired or exhausted passes; it is not an active-access count.

## Trust and administration

- Registry's ERC-8004 and Treasury references, Treasury's ERC-8004 reference, and Pass's Registry reference are constructor immutables.
- Treasury's Registry binding can be changed by its owner before ownership renunciation. The setter itself is not a one-time guard. Ownership renunciation permanently finalizes the configured Registry binding.
- MibboPass retains an owner who manages the usage relayer allowlist.
- Agent owners control their own pass configurations and current pause state; Pass administration does not grant those rights.
- The three Mibbo contracts are deployed directly, without a Mibbo upgrade proxy. The external ERC-8004 registry has its own implementation and governance boundary.

## Integration boundaries

The application prepares and hosts metadata, coordinates wallet signatures and transactions, verifies deployment receipts, runs agents, and submits authorized usage transactions. These offchain responsibilities are not implemented by this contract repository.

Agent-token issuance, Doppler pools, trading-fee claims, vesting, and ERC-8004 reputation contracts are separate integrations. MibboPass accepts a configured ERC-20 payment token but does not create it, operate its liquidity pool, or distribute its trading fees. Treasury holds identity NFTs; subscription fees are paid directly to agent creators.

## Source layout

```text
README.md                   Architecture, contract behavior, and production addresses
contracts/
  MibboRegistry.sol         Agent identity and beneficial ownership
  MibboTreasury.sol         ERC-8004 NFT custody and authorized writes
  MibboPass.sol             Versioned access passes and usage accounting
  interfaces/              Shared Solidity types, interfaces, errors, and events
docs/
  ARCHITECTURE.md           Contract relationships and lifecycle diagrams
  contracts-overview.md     Public functions and access controls
  overview.md               Identity, access, and application boundaries
```

The contracts use Solidity 0.8.30 and import `@openzeppelin/contracts` (`^5.6.1`).

## Further reading

- [Core architecture](docs/ARCHITECTURE.md)
- [Contract interfaces and registration flow](docs/contracts-overview.md)
- [Identity and custody overview](docs/overview.md)
