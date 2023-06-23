const { expect } = require("chai");
const { ethers } = require("hardhat");
const chai = require("chai");
chai.use(require("chai-bignumber")(ethers.BigNumber));
const { describe } = require("mocha");

let comptroller,
  token1,
  token2,
  ctoken1,
  ctoken2,
  interestRateModel,
  governor,
  timelock;
describe("Governor", async function () {
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

    const TimeLock = await ethers.getContractFactory("Timelock");
    timelock = await TimeLock.deploy(owner.address, 432000);
    await timelock.deployed();

    const Governor = await ethers.getContractFactory("Governor");
    governor = await Governor.deploy(comptroller.address, timelock.address);
    await governor.deployed();

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

  it.only("Propose", async function () {
    await expect(
      governor.propose("There should be more than 2 markets in a pool")
    ).to.be.revertedWith("Proposer does not have enough collateral to propose");

    await token1.approve(ctoken1.address, 1000);
    await ctoken1.mintToken(1000);

    await token2.approve(ctoken2.address, 1000);
    await ctoken2.mintToken(1000);

    await comptroller.enterMarket(ctoken1.address);
    await comptroller.enterMarket(ctoken2.address);

    expect(
      await governor.propose("There should be more than 2 markets in a pool")
    ).to.emit(governor, "ProposalCreated");

    expect(await governor.state(1)).to.eq(0); // state should be pending
  });

  it.only("castVote", async function () {
    await expect(governor.castVote(2, true)).to.be.revertedWith(
      "Invalid proposalId"
    );
    expect(await governor.castVote(1, true)).to.emit(governor, "VoteCast");
    expect(governor.castVote(1, false)).to.be.revertedWith(
      "Voter has already voted"
    );

    expect(await governor.getCurrentVotes(1)).to.eqls(2);
  });

});
