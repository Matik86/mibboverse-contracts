# Contract architecture: MibboRegistry · MibboTreasury · MibboPass

## 1. Contract relationships

Registry creates identities through ERC-8004 and authorizes privileged writes through Treasury. Treasury holds the identity NFTs. Pass reads beneficial ownership from Registry, accepts purchases, and allows authorized relayers to report usage. The table below describes each binding.

| Relationship | Enforcement | Meaning |
|---|---|---|
| `MibboRegistry → ERC-8004` | `immutable` | Registry registers identity NFTs and reads agent wallets. |
| `MibboRegistry → MibboTreasury` | `immutable` | Registry forwards custody and privileged identity operations to Treasury. |
| `MibboTreasury → ERC-8004` | `immutable` | Treasury is the custodian and executes privileged ERC-8004 calls. |
| `MibboTreasury ← MibboRegistry` | `onlyRegistry` | Only the configured Registry can initialise agents or update their ERC-8004 metadata. The production deployment finalises this binding by renouncing Treasury ownership. |
| `MibboPass → MibboRegistry` | `immutable` | Pass verifies agent ownership and sends subscription fees to the beneficial owner. |
| `MibboPass → relayers` | `onlyOwner` allowlist | The Pass owner can add or remove relayers that record usage. |

## 2. Deployment flow

1. Deploy Treasury and Registry with the external ERC-8004 dependency.
2. Set Registry as the caller trusted by Treasury.
3. Deploy Pass with Registry and an initial relayer.
4. Renounce Treasury ownership to finalize the binding.

The production setup performs ownership renunciation after Registry configuration and Pass deployment. Before renunciation, the owner can still change the binding; the setter has no one-time guard. If the Registry binding is not configured, Treasury rejects all privileged Registry calls.

## 3. Contracts and public responsibilities

### MibboRegistry

**Role:** The central agent registry. It maps `agentId` to the permanent beneficial owner, registers agents, and is the owner-authorisation layer for identity metadata changes. It does not custody the ERC-8004 NFTs itself.

| Function | Caller | Behaviour |
|---|---|---|
| `registerAgent(card, deadline, sig)` | Anyone | Registers an ERC-8004 identity, transfers its NFT to Treasury, initialises the agent wallet, and records the caller as beneficial owner. |
| `updateAgentMetadata(agentId, key, value)` | Agent beneficial owner | Forwards a metadata update through Treasury to ERC-8004. |
| `updateAgentURI(agentId, newURI)` | Agent beneficial owner | Forwards an identity URI update through Treasury to ERC-8004. |
| `getAgentOwner(agentId)` | Anyone | Returns the beneficial owner. |
| `getAgentInfo(agentId)` | Anyone | Returns beneficial owner, ERC-8004 agent wallet, and creation timestamp. |
| `getAgentsByOwner(owner)` | Anyone | Returns all agent IDs registered by an owner. |
| `isOwner(agentId, account)` | Anyone / MibboPass | Checks beneficial ownership. |

### MibboTreasury

**Role:** Custody for ERC-8004 identity NFTs. It is the only contract that performs privileged ERC-8004 writes, and accepts those calls solely from the configured MibboRegistry.

| Function | Caller | Behaviour |
|---|---|---|
| `setAgentRegistry(address)` | Owner, before finalisation | Sets the Registry authorised to use Treasury. The production setup subsequently renounces ownership. |
| `initAgent(agentId, wallet, deadline, sig)` | MibboRegistry | Confirms NFT custody and writes the agent wallet in ERC-8004. |
| `updateMetadata(agentId, key, value)` | MibboRegistry | Calls `erc8004.setMetadata()`. |
| `updateAgentURI(agentId, newURI)` | MibboRegistry | Calls `erc8004.setAgentURI()`. |

### MibboPass

**Role:** A soulbound ERC-1155 access-pass system. Each `agentId` is an ERC-1155 token ID. A purchase transfers the full configured fee to the agent beneficial owner; the pass itself tracks its purchaser-specific expiry, request quota, and configuration version.

| Function | Caller | Behaviour |
|---|---|---|
| `setConfig(agentId, cfg)` | Agent beneficial owner | Creates a new config version containing payment token, fee, duration, request limit, pause state, and metadata URI. |
| `setPaused(agentId, paused)` | Agent beneficial owner | Pauses or resumes the current configuration. |
| `purchasePass(agentId)` | Anyone | Collects the full fee for the beneficial owner, replaces an existing pass for that agent, and mints a soulbound ERC-1155 pass. |
| `hasAccess(user, agentId)` | Anyone / relayer | Returns true only for a held, unpaused, unexpired pass with unused request quota. |
| `recordUsage(agentId, user, count)` | Authorised relayer | Records consumption only while `hasAccess` is true. |
| `batchRecordUsage(agentIds, users, counts)` | Authorised relayer | Records a non-empty batch atomically; any failed item reverts every item. |
| `holderCount(agentId)` | Anyone | Counts current token holders, including expired and exhausted passes. |
| `setRelayer(address, status)` | Pass owner | Adds or removes a usage relayer. |
| `getPassStatus(user, agentId)` | Anyone | Returns access state, expiry, quota use, and the purchased config version. |
| `getUserPasses(user)` / `getActivePasses(user)` | Anyone | Returns all recorded or currently active agent passes. |
| `getCurrentConfig(agentId)` / `getConfig(agentId, version)` | Anyone | Returns the current or a historical configuration version. |
| `getConfigURI(agentId, version)` / `uri(agentId)` | Anyone | Returns a historical configuration URI or the current ERC-1155 metadata URI. |

## 4. Core flows

### Agent registration

![Agent registration flow: User, Registry, ERC-8004, and Treasury](images/register_flow.png)

1. The user calls `MibboRegistry.registerAgent(card, walletDeadline, walletSig)`.
2. Registry calls ERC-8004 `register(card.endpoint)`.
3. ERC-8004 mints the identity NFT to Registry and returns its `agentId`.
4. Registry transfers the NFT to MibboTreasury with `safeTransferFrom`.
5. Registry calls Treasury `initAgent` with the new ID, caller wallet, deadline, and signature.
6. Treasury verifies custody and calls ERC-8004 `setAgentWallet`.
7. Control returns to Registry, which records the caller as beneficial owner.
8. Registry emits `AgentRegistered`; the transaction succeeds only if every preceding operation succeeds.

Pass configuration follows registration: the beneficial owner calls `MibboPass.setConfig` to define access terms and metadata. This is a separate contract call, even when the wallet submits both calls together.

### Pass purchase and usage

1. The buyer approves the configured ERC-20 and calls `purchasePass(agentId)`.
2. Pass reads the beneficial owner from Registry and transfers the full subscription fee to that owner.
3. Pass replaces any previous pass for the buyer and agent, mints one soulbound ERC-1155 token, and stores expiry and quota.
4. An authorized relayer calls `recordUsage` or `batchRecordUsage` as requests are consumed.
5. Access ends when the pass expires, its quota is exhausted, or the current agent configuration is paused.

## 5. Post-deployment mutability

| Item | Contract | Authority | Change |
|---|---|---|---|
| Agent beneficial owner | MibboRegistry | None | Immutable after registration. |
| ERC-8004 address | MibboRegistry / MibboTreasury | None | Constructor `immutable`. |
| Treasury address | MibboRegistry | None | Constructor `immutable`. |
| Registry address | MibboTreasury | None after production finalisation | Set during deployment, then Treasury ownership is renounced. |
| Pass Registry address | MibboPass | None | Constructor `immutable`. |
| Pass configuration and metadata URI | MibboPass | Agent beneficial owner | `setConfig(agentId, cfg)`. |
| Current pass pause state | MibboPass | Agent beneficial owner | `setPaused(agentId, paused)`. |
| Usage relayer allowlist | MibboPass | Pass owner | `setRelayer(address, status)`. |

## 6. Invariants

- ERC-8004 identity NFTs are held by MibboTreasury, not by their creators.
- Only MibboRegistry can trigger Treasury's privileged ERC-8004 operations.
- MibboRegistry has no global owner or administrator.
- MibboPass tokens cannot be transferred between non-zero addresses.
- A relayer cannot record usage for a missing, paused, expired, or quota-exhausted pass.
- A configuration URI is versioned with its pass configuration; `uri(agentId)` exposes the latest version through the ERC-1155 standard.
