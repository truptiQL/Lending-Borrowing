const { ethers, upgrades } = require("hardhat");

async function main() {
  const LendingAndBorrowingv1 = await ethers.getContractFactory("LendingAndBorrowingv1");
  const lendingAndBorrowingv1 = await upgrades.upgradeProxy("0xaa2D6608241B6B930BCcaFE245eFDf052e46C9aA", LendingAndBorrowingv1);
  console.log("LendingAndBorrowing upgraded");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});