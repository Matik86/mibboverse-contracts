import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("GenesisNFTModule", (m) => {
  const genesis = m.contract("GenesisNFT", [
    "Genesis",
    "OG",
    "Genesis of the Mibboverse",
    "ipfs://hidden.json"
  ]);

  return { genesis };
});