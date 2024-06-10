import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const BlotteryModule = buildModule("BlotteryModule", (m) => {
  const blottery = m.contract("Blottery", [], {});

  return { blottery };
});

export default BlotteryModule;
