const { ethers, upgrades } = require("hardhat");

async function main() {
  const Token2 = await ethers.getContractFactory("ERC20");
  const token2 = await Token2.deploy("Token2", "T2", 18);
  await token2.deployed();
  console.log("token2 deployed to: ", token2.address);

  // TO verify the contract
  await hre.run("verify:verify", {
    address: token2.address,
    constructorArguments: ["Token2", "T2", 18],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

//0x5230c2bbbe5b44413C9e61e7080Cd84880dDe948