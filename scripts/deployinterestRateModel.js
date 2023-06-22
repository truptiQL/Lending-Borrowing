const { ethers, upgrades } = require("hardhat");

async function main() {
  const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
   interestRateModel = await InterestRateModel.deploy( 2,
    5,
    7,
    9,
    "0x9cc6F5f16498fCEEf4D00A350Bd8F8921D304Dc9");
  await interestRateModel.deployed();
  console.log("interestRateModel deployed to: ", interestRateModel.address);

  // TO verify the contract
  await hre.run("verify:verify", {
    address: interestRateModel.address,
    constructorArguments: [2,
        5,
        7,
        9,
        "0x9cc6F5f16498fCEEf4D00A350Bd8F8921D304Dc9"],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// 0x4f623D9bA20018C939b89489EF0f97412c12B52f: 