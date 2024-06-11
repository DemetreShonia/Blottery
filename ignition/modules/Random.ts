import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const RandomModule = buildModule("RandomModule", (m) => {
  const randomContract = m.contract("RandomContract", [], {});

  return { randomContract };
});

export default RandomModule;
