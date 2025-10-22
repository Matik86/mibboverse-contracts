![Base](logo.webp)

<!-- Badge row 1 - links and profiles -->

[![Website mibboverse.com](https://lime-abundant-constrictor-231.mypinata.cloud/ipfs/bafkreiaqhcvyd2cuy3lsmzsjzku7ywbhlopqv2zqfwbx3m65gprmjrozhy)](https://mibboverse.com/)
[![Blog](https://mibboverse.com/img/par.svg)](https://paragraph.com/@mibboverse)
[![Farcaster](https://mibboverse.com/img/farcaster.svg)](https://farcaster.xyz/mibboverse.eth)
[![Twitter Mibboverse](https://mibboverse.com/img/x.svg)](https://x.com/mibboverse)

# 🌀 Mibboverse
Mibboverse – a new gaming universe built on the Base ecosystem, where luck and chaos are the constant companions of everything within it.

> This repository contains the smart contracts that power the game.

## ▶️ Deployed Contracts

All contracts are deployed on **Base**

| Address  | Name | Contracts Overview |
| ------------- | ------------- | ------------- |
|  [0x8792fB6633F207A6E5171E5cf34c0B9594a39Cc4](https://basescan.org/address/0x8792fB6633F207A6E5171E5cf34c0B9594a39Cc4) | Crystals Proxy Contract | ERC20 token used as in-game currency |
|  [0x32a388e3BD3ae8C4Ba9918604A9690d0dED9d192](https://basescan.org/address/0x32a388e3bd3ae8c4ba9918604a9690d0ded9d192) | CrystalsV2 Implementation Contract | |
|  [0x254737e8Ad378deB9fd8fB228Dea279bb7FCe5A3](https://basescan.org/address/0x254737e8Ad378deB9fd8fB228Dea279bb7FCe5A3) | Artifacts1155 | ERC1155 NFT representing collectible game artifacts |
|  [0xdDa12482811FA76F3d1C23b548C495EEeE9F23C5](https://basescan.org/address/0xdDa12482811FA76F3d1C23b548C495EEeE9F23C5) | TokenVault | Contract for claiming rewards by users |

## 📂 Project Structure

```
mibboverse-contracts
│
├── contracts
│   ├── ArtifactsERC1155.sol
│   ├── CrystalsProxy_v2.sol
│   ├── ProxyExample.sol
│   ├── GenesisNFT.sol
│   ├── TestERC20.sol
│   ├── TokenVault.sol
│   └── TestERC20.sol
│
├── ignition
│   └── modules
│       ├── ArtifactsERC1155.ts
│       ├── CrystalsV2.ts
│       ├── GenesisNFT.ts
│       └── TokenVault.ts
│
├── test
│   ├── ArtifactsERC1155.ts
│   ├── CrystalsProxy_v2.ts
│   ├── GenesisERC721.ts
│   └── TokenVault.ts
│
├── .gitignore
├── README.md
├── hardhat.config.ts
├── logo.webp
├── package.json
└── tsconfig.json
```

## 🚀 Installation

> To run this project locally, you need **Node.js** and **Hardhat** installed.

1. Clone the repository:

```bash
git clone https://github.com/<your-username>/mibboverse-contracts.git
cd mibboverse-contracts
```

2. Install dependencies:

```bash
npm install
```

3. (Optional) Install Hardhat globally if you haven't yet:

```bash
npm install --save-dev hardhat
```

4. Configure environment variables for deployment (if needed):

```env
BASE_SEPOLIA_RPC_URL=your_rpc_url
PRIVATE_KEY=your_private_key
```

## 🛠 Common Commands

| Command | Description |
| --- | --- |
| `npx hardhat compile` | Compile all smart contracts |
| `npx hardhat test` | Run tests for contracts |

Deploy contracts on the Base Sepolia
```bash
npx hardhat run ignition/modules/ArtifactsERC1155.ts --network baseSepolia
```
```bash
npx hardhat run ignition/modules/CrystalsV2.ts --network baseSepolia
```
```bash
npx hardhat run ignition/modules/GenesisNFT.ts --network baseSepolia
```
```bash
npx hardhat run ignition/modules/TokenVault.ts --network baseSepolia
```




