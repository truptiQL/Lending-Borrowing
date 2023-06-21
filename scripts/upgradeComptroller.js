const { ethers, upgrades } = require("hardhat");

async function main() {
  const Comptrollerv1 = await ethers.getContractFactory("Comptrollerv1");
  const comptrollerv1 = await upgrades.upgradeProxy(
    "0x60EA0818496725bde1409FAE3B63DFE5Be94Ad0D",
    Comptrollerv1
  );
  console.log("comptroller upgraded at ", comptrollerv1.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
