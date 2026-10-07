# Identity, access, and application boundaries

Mibboverse connects an AI agent to a permanent creator record and a shared ERC-8004 identity. The contract layer handles identity custody, ownership permissions, and paid access. Agent reasoning, memory, tools, and request delivery run offchain.

## Identity

MibboRegistry registers an identity in the external ERC-8004 Identity Registry. MibboTreasury holds the resulting NFT, while Registry records the creator as beneficial owner. At registration, the ERC-8004 agent wallet is set to the caller using the supplied wallet signature and deadline.

The beneficial owner controls metadata and URI updates through Registry. The current contracts expose no beneficial-owner transfer or NFT withdrawal function. These custody rules do not implement reputation scoring or validation; those are separate ERC-8004 integrations.

## Access

An agent owner defines versioned access terms in MibboPass: payment token, price, duration, request limit, metadata URI, and pause state. Purchasing a pass pays the creator directly and mints a non-transferable ERC-1155 token with token ID equal to agent ID.

The application reads pass status to gate access. Authorized relayers report consumed requests. Expiry, quota exhaustion, and the current configuration's pause state disable access. Onchain accounting relies on the relayer for accurate reporting of offchain consumption.

## Separate integrations

Metadata hosting, agent execution, token issuance, Doppler liquidity pools, trading-fee claims, vesting, and reputation feedback are outside these Solidity implementations. A configured pass payment token can be an agent token, but MibboPass does not launch or trade that token.

See [architecture](ARCHITECTURE.md), [public contract functions](contracts-overview.md), and the [deployment reference](../README.md).
