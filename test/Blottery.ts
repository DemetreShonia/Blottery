import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Blottery", function () {
  // describe
  //     let Blottery, owner, addr;
  //     beforeEach(async function () {
  //         Blottery = await ethers.getContractFactory("Blottery");
  //         [owner, addr] = await ethers.getSigners();
  //     });
  //   it("Should return Get Game Price", async function () {
  //     const Blottery = await ethers.getContractFactory("Blottery");
  //     const blottery = await Blottery.deploy();
  //     expect(await blottery.getPlayerGameStatuses(addr)).to.equal("Hello, world!");
  //     await blottery.setGreeting("Hola, mundo!");
  //     expect(await blottery.getGreeting()).to.equal("Hola, mundo!");
  //   });

  async function deployBlottery() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const Blottery = await hre.ethers.getContractFactory("Blottery");
    const blottery = await Blottery.deploy();

    return { blottery, owner, otherAccount };
  }
  describe("Deployment", function () {
    it("Should deploy Blottery", async function () {
      const { blottery } = await deployBlottery();
      expect(blottery.gameBalances(0)).to.not.equal(0);
    });
  });
});
