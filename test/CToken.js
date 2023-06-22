const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { describe } = require("mocha");

let comptroller, token1, token2, ctoken1, ctoken2, interestRateModel;
describe("CToken functions", async function () {
  before(async function () {
    const [owner] = await ethers.getSigners();

    const InterestRateModel = await ethers.getContractFactory(
      "InterestRateModel"
    );
    interestRateModel = await InterestRateModel.deploy(
      2,
      5,
      7,
      9,
      owner.address
    );
    await interestRateModel.deployed();

    const Comptroller = await ethers.getContractFactory("Comptroller");
    comptroller = await Comptroller.deploy();
    await comptroller.deployed();

    const Token1 = await ethers.getContractFactory("ERC20");
    token1 = await Token1.deploy("Token1", "T1", 18);
    await token1.deployed();

    const Token2 = await ethers.getContractFactory("ERC20");
    token2 = await Token2.deploy("Token2", "T2", 18);
    await token2.deployed();

    const CToken1 = await ethers.getContractFactory("CToken");
    ctoken1 = await CToken1.deploy();
    await ctoken1.deployed();

    const CToken2 = await ethers.getContractFactory("CToken");
    ctoken2 = await CToken2.deploy();
    await ctoken2.deployed();

    ctoken1.initialize(
      "cToken1",
      "CT1",
      8,
      comptroller.address,
      interestRateModel.address,
      token1.address
    );

    ctoken2.initialize(
      "cToken2",
      "CT2",
      8,
      comptroller.address,
      interestRateModel.address,
      token2.address
    );

    comptroller.initialize();
    await comptroller.supportMarket(ctoken1.address);

    await comptroller.supportMarket(ctoken2.address);
  });

  it("mintToken", async function () {
    await expect(ctoken1.mintToken(2000)).to.be.revertedWith(
      "Insufficient allowance for this transaction"
    );

    await token1.approve(ctoken1.address, 30000);
    expect(await ctoken1.mintToken(2000)).to.emit(ctoken1, "Mint");

    expect(await ctoken1.totalSupply()).to.eq(2000);
    expect(await ctoken1.currentExchangeRate()).to.eq(1);
  });

  it("redeemTokens", async function () {
    const [owner] = await ethers.getSigners();

    await expect(ctoken1.redeemTokens(owner.address, 2)).to.be.revertedWith(
      "Redeem not allowed"
    );

    await comptroller.enterMarket(ctoken1.address);

    expect(await ctoken1.redeemTokens(owner.address, 2000)).to.emit(
      ctoken1,
      "Redeem"
    );
    expect(await ctoken1.totalSupply()).to.eq(0);
  });

  it("borrow", async function () {
    const [owner, addr] = await ethers.getSigners();
    await expect(ctoken1.borrow(addr.address, 10000000000)).to.be.revertedWith(
      "This much amount is not available"
    );

    await token1.approve(ctoken1.address, 200);
    await ctoken1.mintToken(200);
    await comptroller.enterMarket(ctoken1.address);

    await token2.mint(addr.address, 5000000);

    await token2.connect(addr).approve(ctoken2.address, 20000);
    await ctoken2.connect(addr).mintToken(20000);
    await comptroller.enterMarket(ctoken2.address);

    await expect(ctoken1.borrow(addr.address, 20)).to.be.revertedWith(
      "Insufficient liquidity"
    );
    expect(await ctoken2.borrow(owner.address, 2000)).to.emit(
      ctoken1,
      "Borrow"
    );

    expect(await ctoken2.totalBorrows()).to.eq(2000);
    expect(await ctoken2.totalSupply()).to.eq(20000);
  });

  it("repayBorrow", async function () {
    const [owner, addr] = await ethers.getSigners();

    expect(
      ctoken1.repayBorrow(owner.address, 10000, token1.address, "cToken1")
    ).to.be.revertedWith("Invalid borrow amount");

    await token2.approve(ctoken2.address, 20);
    await ctoken2.repayBorrow(owner.address, 20);
  });
});
