const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MockPriceOracle contract", function () {
  describe("updatePrice()", async () => {
    it("sets the price", async () => {
      const MockFactory = await ethers.getContractFactory("MockPriceOracle");
      const contract = await MockFactory.deploy();

      const cTokenAddress = ethers.Wallet.createRandom().address;
      await contract.updatePrice(cTokenAddress, 10);

      expect(await contract.prices(cTokenAddress)).to.eq(10);
    });
  });

  describe("getUnderlyingPrice()", async () => {
    it("returns 0 if the price hasn't been set", async () => {
      const MockFactory = await ethers.getContractFactory("MockPriceOracle");
      const contract = await MockFactory.deploy();

      const cTokenAddress = ethers.Wallet.createRandom().address;

      expect(await contract.getUnderlyingPrice(cTokenAddress)).to.eq(0);
    });

    it("returns the price if the price has been set", async () => {
      const MockFactory = await ethers.getContractFactory("MockPriceOracle");
      const contract = await MockFactory.deploy();

      const cTokenAddress = ethers.Wallet.createRandom().address;
      await contract.updatePrice(cTokenAddress, 10);

      expect(await contract.getUnderlyingPrice(cTokenAddress)).to.eq(10);
    });
  });
});
