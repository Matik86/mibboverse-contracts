# Mibboverse core architecture

The core consists of `MibboRegistry`, `MibboTreasury`, and `MibboPass`.

For the registration flow and public contract surface, see the [contract overview](contracts-overview.md).

## Trust boundaries

![Agent registration flow: User, Registry, ERC-8004, and Treasury](images/register_flow.png)

The four vertical participants are the creator, MibboRegistry, the external ERC-8004 Identity Registry, and MibboTreasury. Registration creates an identity NFT, moves it into Treasury custody, and sets the agent wallet before recording beneficial ownership. MibboPass subsequently reads that ownership record to authorize pass configuration and route subscription fees.

### MibboRegistry

Registry records an immutable-in-practice beneficial owner for each newly registered `agentId`. It has no `Ownable` inheritance or global administrator. The agent beneficial owner alone may update that agent's ERC-8004 metadata and URI through the Registry.

Registry's ERC-8004 and Treasury addresses are constructor immutables.

### MibboTreasury

Treasury owns the ERC-8004 identity NFT after registration and is the sole component that calls ERC-8004's privileged wallet, metadata, and URI functions. `onlyRegistry` permits those Treasury functions only for the configured Registry.

The production setup configures the Registry and then calls `renounceOwnership()`. The owner becomes `address(0)`, so the trusted Registry cannot subsequently be changed. Before renunciation, the owner can change the Registry binding; the setter itself does not enforce a one-time initialization.

### MibboPass

MibboPass is a soulbound ERC-1155. An ERC-1155 `tokenId` equals `agentId`, so marketplace metadata resolution uses the standard `uri(agentId)` interface.

- The beneficial owner creates a versioned pass configuration via `setConfig`.
- A config contains payment token, full subscription fee, duration, request limit, pause state, and a metadata URI.
- `purchasePass` sends the entire fee directly to `MibboRegistry.getAgentOwner(agentId)`.
- A purchase replaces the buyer's previous pass for the same agent.
- Each purchased pass stores its own expiry, quota counters, and config version in `UserPassState`.
- `recordUsage` is restricted to the MibboPass relayer allowlist and rejects a missing, paused, expired, or quota-exhausted pass.

`MibboPass` retains an owner who manages the relayer allowlist. Usage relayers can record consumption but cannot configure an agent's pass terms.

## Agent lifecycle

1. The creator signs the ERC-8004 `AgentWalletSet` typed data for the next agent ID, naming Treasury as the NFT owner.
2. The creator calls `MibboRegistry.registerAgent`.
3. Registry registers the ERC-8004 identity NFT and transfers it to Treasury.
4. Registry calls `MibboTreasury.initAgent`; Treasury verifies NFT custody and calls ERC-8004 `setAgentWallet`.
5. Registry records the creator as `beneficialOwner` and emits `AgentRegistered`.

The identity NFT and reputation cannot be transferred by the creator because Treasury retains custody. The beneficial owner is an onchain registry record used for authorisation and payment routing.

## Pass lifecycle and metadata

1. An agent beneficial owner calls `MibboPass.setConfig(agentId, cfg)`.
2. The call creates a new configuration version and stores its metadata URI with that version.
3. A buyer approves the configured ERC-20 and calls `purchasePass(agentId)`.
4. MibboPass mints one soulbound ERC-1155 token with `tokenId == agentId` and stores user-specific state.
5. An authorised relayer calls `recordUsage` as offchain requests are consumed.

The current ERC-1155 URI is available through `uri(agentId)`. Historical config URIs remain readable through `getConfigURI(agentId, version)`. Changing a configuration affects future purchases; pausing the current config immediately makes `hasAccess` false for all holders of that agent's pass.

## Deployment finalisation

1. Deploy MibboTreasury with the external ERC-8004 Identity Registry address.
2. Deploy MibboRegistry with the same ERC-8004 address and the Treasury address.
3. Configure Treasury to accept privileged calls from that Registry.
4. Deploy MibboPass with the Registry address and the initial usage relayer.
5. Renounce Treasury ownership to permanently finalize the Registry binding.

Usage can also be reported through `batchRecordUsage`. Every item follows the same access rules as `recordUsage`; any failure reverts the whole batch. `holderCount` counts token holders, including holders whose access has expired or exhausted its quota.
