const { ethers, upgrades } = require("hardhat");

async function main() {
  const Token1 = await ethers.getContractFactory("ERC20");
  const token1 = await Token1.deploy("Token1", "T1", 18);
  await token1.deployed();
  console.log("token1 deployed to: ", token1.address);

  // TO verify the contract
  await hre.run("verify:verify", {
    address: token1.address,
    constructorArguments: ["Token1", "T1", 18],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

//0xe2a8b260a1B65E42740CE9b1901D8609CCCBE17A