// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const Token1 = await ethers.getContractFactory("Token1");
  const Token = await upgrades.deployProxy(Token1,["Token1", "T1", 18, "address"],{
    initializer: "initialize"
  });
  await Token.deployed();
  console.log("Token1 contract deployed to: ", Token.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
