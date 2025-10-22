import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("CrystalsV2Module", (m) => {
  // Implementation deployment
  const crystalsImpl = m.contract("CrystalsV2");

  // Encode initialize for proxy
  const initData = m.encodeFunctionCall(crystalsImpl, "initialize", [
    "Crystals",
    "CRYS",
  ]);

  const proxy = m.contract("ProxyExample", [crystalsImpl, initData]);

  return { crystalsImpl, proxy };
});
