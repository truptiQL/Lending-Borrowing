const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
const { describe } = require("mocha");
require("dotenv").config();
const helpers = require("@nomicfoundation/hardhat-network-helpers");

let comptroller, token1, ctoken1, ctoken2, token2;
describe("LendingAndBorrowing", async function () {
  before(async function () {
    const provider = new ethers.providers.JsonRpcProvider(
      process.env.SEPOLIA_URL
    );

    signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

    comptroller = await ethers.getContractAt(
      "Comptroller",
      "0x60EA0818496725bde1409FAE3B63DFE5Be94Ad0D",
      signer
    );

    token1 = await ethers.getContractAt(
      "ERC20",
      "0xe2a8b260a1B65E42740CE9b1901D8609CCCBE17A"
    );

    token2 = await ethers.getContractAt(
      "ERC20",
      "0x5230c2bbbe5b44413C9e61e7080Cd84880dDe948"
    );

    ctoken1 = await ethers.getContractAt(
      "CToken",
      "0xfD909101E1893C6E60996Acf451c701931D1C40D",
      signer
    );

    ctoken2 = await ethers.getContractAt(
      "CToken",
      "0x62941EEf1Bf2230783E453b5ED42A3ab2e05011f"
    );

    address = "0x9cc6F5f16498fCEEf4D00A350Bd8F8921D304Dc9";
    await helpers.impersonateAccount(address);
    impersonatedSigner = await ethers.getSigner(address);

    addr = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199";
    await helpers.impersonateAccount(address);
    impersonateSignerAddr = await ethers.getSigner(addr);
  });

  it("mintToken", async function () {
    await expect(
      ctoken1.connect(impersonatedSigner).mintToken(1000000000000)
    ).to.be.revertedWith("Insufficient allowance for this transaction");

    await token1.mint(address, 500000);
    await token1.approve(ctoken1.address, 3000);

    expect(await ctoken1.connect(impersonatedSigner).mintToken(3000)).to.emit(
      ctoken1,
      "Mint"
    );
    expect(await ctoken1.totalSupply()).to.eq(3000);
    expect(await ctoken1.currentExchangeRate()).to.eq(1);
  });

  it("redeemTokens", async function () {
    await expect(
      ctoken1.connect(impersonatedSigner).redeemTokens(address, 200000)
    ).to.be.revertedWith("Insufficient liquidity");

    await comptroller.connect(impersonatedSigner).enterMarket(ctoken1.address);

    expect(
      await ctoken1.connect(impersonatedSigner).redeemTokens(address, 2)
    ).to.emit(ctoken1, "Redeem");
  });

  it("borrow", async function () {
    await expect(
      ctoken1.connect(impersonatedSigner).borrow(addr, 10000000000)
    ).to.be.revertedWith("This much amount is not available");

    await token1.connect(impersonatedSigner).approve(ctoken1.address, 200);
    await ctoken1.connect(impersonatedSigner).mintToken(200);
    await comptroller.connect(impersonatedSigner).enterMarket(ctoken1.address);

    await token2.mint(addr, 5000);

    await token2.connect(impersonateSignerAddr).approve(ctoken2.address, 2000);
    await ctoken2.connect(impersonateSignerAddr).mintToken(2000);
    await comptroller.connect(impersonatedSigner).enterMarket(ctoken2.address);

    await expect(
      ctoken1.connect(impersonatedSigner).borrow(addr, 200)
    ).to.be.revertedWith("Insufficient liquidity");
    expect(
      await ctoken2.connect(impersonatedSigner).borrow(address, 200)
    ).to.emit(ctoken1, "Borrow");

    expect(await ctoken2.totalBorrows()).to.eq(200);
    expect(await ctoken2.totalSupply()).to.eq(2000);
  });

  it("repayBorrow", async function () {
    expect(
      ctoken1
        .connect(impersonatedSigner)
        .repayBorrow(address, 10000, token1.address, "cToken1")
    ).to.be.revertedWith("Invalid borrow amount");

    token2.mint(address, 10000000000);
    await token2.connect(impersonatedSigner).approve(ctoken2.address, 20);
    await ctoken2.connect(impersonatedSigner).repayBorrow(address, 20);
  });
});
