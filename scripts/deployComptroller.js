// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
let comptroller;

async function main() {
  const Comptroller = await ethers.getContractFactory("Comptroller");
  comptroller = await upgrades.deployProxy(Comptroller);
  await comptroller.deployed();
  console.log("comptroller contract deployed to: ", comptroller.address);
  // TO verify the contract
  await hre.run("verify:verify", {
    address: comptroller.address,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
// 0x60EA0818496725bde1409FAE3B63DFE5Be94Ad0D : proxy
// 0xe9Ca9C03e8dAfcce7081213D03427407F4fd267D : Implementation