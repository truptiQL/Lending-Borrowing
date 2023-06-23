// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
let ctoken2;
let comptroller = "0x60EA0818496725bde1409FAE3B63DFE5Be94Ad0D";
let interestRateModel = "0x4f623D9bA20018C939b89489EF0f97412c12B52f";
let underlyingToken2 = "0x5230c2bbbe5b44413C9e61e7080Cd84880dDe948";

async function main() {
  const Ctoken = await ethers.getContractFactory("CToken");
  ctoken2 = await upgrades.deployProxy(
    Ctoken,
    ["CToken2", "CT2", 8, comptroller, interestRateModel, underlyingToken2],
    {
      initializer: "initialize",
    }
  );
  await ctoken2.deployed();
  console.log("ctoken contract deployed to: ", ctoken2.address);
  // TO verify the contract
  await hre.run("verify:verify", {
    address: ctoken2.address,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// proxy  = 0x62941EEf1Bf2230783E453b5ED42A3ab2e05011f
