import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("TokenVaultModule", (m) => {

  const vault = m.contract("TokenVault");

  return {vault};
});