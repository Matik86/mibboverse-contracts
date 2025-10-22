import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ArtifactsERC1155Module", (m) => {
  const artifacts = m.contract("ArtifactsERC1155", []);

  return { artifacts };
});
