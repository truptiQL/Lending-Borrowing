const hre = require("hardhat");

async function main() {
  const Token2 = await ethers.getContractFactory("Token2");
  const Token = await upgrades.deployProxy(Token2,["Token2", "T2", 18, "address"],{
    initializer: "initialize"
  });
  await Token.deployed();
  console.log("Token2 contract deployed to: ", Token.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
