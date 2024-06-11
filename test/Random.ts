import { time, loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("Random", function () {
  async function deployRandom() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const RandomContract = await hre.ethers.getContractFactory("RandomContract");
    const randomContract = await RandomContract.deploy();

    return { randomContract, owner, otherAccount };
  }
  describe("Deployment", function () {
    it("Should deploy Random", async function () {
      const { randomContract, owner } = await loadFixture(deployRandom);

      // randomContract.requestRandomNumber();

      //   expect(randomContract).to.not.equal(owner.address);
    });
  });
});
