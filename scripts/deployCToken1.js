// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
let ctoken1;
let comptroller = "0x60EA0818496725bde1409FAE3B63DFE5Be94Ad0D";
let interestRateModel = "0x4f623D9bA20018C939b89489EF0f97412c12B52f";
let underlyingToken1 = "0xe2a8b260a1B65E42740CE9b1901D8609CCCBE17A";

async function main() {
  const Ctoken = await ethers.getContractFactory("CToken");
  ctoken1 = await upgrades.deployProxy(
    Ctoken,
    ["CToken1", "CT1", 8, comptroller, interestRateModel, underlyingToken1],
    {
      initializer: "initialize",
    }
  );
  await ctoken1.deployed();
  console.log("ctoken contract deployed to: ", ctoken1.address);
  // TO verify the contract
  await hre.run("verify:verify", {
    address: ctoken1.address,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// 0xfD909101E1893C6E60996Acf451c701931D1C40D : proxy
// 0xD9142b179D9bc8CF3FeD06C668a3ED2bc1a560d5: implementation