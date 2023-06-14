const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { describe } = require("mocha");

describe("CToken functions", async function () {
  before(async function () {
    const LendingAndBorrowing = await ethers.getContractFactory("LendingAndBorrowing");
    lendingAndBorrowing = await LendingAndBorrowing.deploy();
    await lendingAndBorrowing.deployed();

    const Token1 = await ethers.getContractFactory("Token1");
    token1 = await Token1.deploy("Token1", "T1", 18, lendingAndBorrowing.address);
    await token1.deployed();

    const Token2 = await ethers.getContractFactory("Token2");
    token2 = await Token2.deploy("Token2", "T1", 18, lendingAndBorrowing.address);
    await token2.deployed();
  });

  it("mint", async function () {
    await token1.initialize();
    await expect(token1.mint(200, token1.address)).to.be.reverted;

  });
});
