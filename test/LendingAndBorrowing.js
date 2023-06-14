const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { describe } = require("mocha");

describe("LendingAndBorrowing", async function () {
  before(async function () {
    const LendingAndBorrowing = await ethers.getContractFactory(
      "LendingAndBorrowing"
    );
    lendingAndBorrowing = await LendingAndBorrowing.deploy();
    await lendingAndBorrowing.deployed();

    const Token1 = await ethers.getContractFactory("Token1");
    token1 = await Token1.deploy("Token1", "T1", 18);
    await token1.deployed();

    const Token2 = await ethers.getContractFactory("Token2");
    token2 = await Token2.deploy("Token1", "T1", 18);
    await token2.deployed();

    const InterestRateModel = await ethers.getContractFactory(
      "InterestRateModel"
    );
    interestRateModel = await InterestRateModel.deploy();
    await interestRateModel.deployed();
  });

  it("enterMarket", async function () {
    const [, addr1] = await ethers.getSigners();

    expect(await lendingAndBorrowing.enterMarket(addr1.address)).to.emit(
      lendingAndBorrowing,
      "MarketAdded"
    );
  });

  it("exitMarket", async function () {
    const [, addr1, addr2] = await ethers.getSigners();

    // expect(await lendingAndBorrowing.exitMarket(addr1.address)).to.emit(
    //   lendingAndBorrowing,
    //   "MarketExit"
    // );
    await expect(
      lendingAndBorrowing.exitMarket(addr2.address)
    ).to.be.revertedWith("Market is not there");
  });

  it("isUnderWater", async function () {
    expect(await lendingAndBorrowing.isUnderwater(token1.address, 90)).to.be.true;
  });

  it("redeemAllowed", async function () {
    const [, addr1] = await ethers.getSigners();

    await lendingAndBorrowing.enterMarket(token1.address);
    await lendingAndBorrowing.addToTheMarket(token1.address, addr1.address);

    expect(await lendingAndBorrowing.redeemAllowed(token1.address, addr1.address)).to.be.true;

    expect(
      await lendingAndBorrowing.redeemAllowed(token2.address, addr1.address)
    ).to.be.revertedWith("Market not listed");
  });

  it("borrowAllowed", async function () {
    await lendingAndBorrowing.enterMarket(token1.address);
    expect(await lendingAndBorrowing.borrowAllowed(token1.address)).to.be.true;
    expect(await lendingAndBorrowing.borrowAllowed(token2.address)).to.be.false;
  });

  it("addToTheMarket", async function () {
    const [owner] = await ethers.getSigners();
    await expect(lendingAndBorrowing.addToTheMarket(token2.address, owner.address)).to.be.revertedWith(
      "Market not listed"
    );
    await lendingAndBorrowing.enterMarket(token1.address);
    expect(await lendingAndBorrowing.addToTheMarket(token1.address, owner.address)).to.emit(lendingAndBorrowing, "AddedToTheMarket");
  });
});
