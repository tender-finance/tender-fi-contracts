import hre, { ethers } from "hardhat";
import { readFileSync, writeFileSync } from "fs";
import { numToWei } from "../utils/ethUnitParser";

const outputFilePath = `./deployments/${hre.network.name}.json`;

// Protocol Params
const params = {
  maxAssets: "20",
  closeFactor: "0.5",
  liquidationIncentive: "1.05",
  oracle: "0xa5BE1a46BB24572066FD61BD752EA4B2B0e2dFc3",
};

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));

  const Unitroller = await hre.ethers.getContractFactory("Unitroller");
  const unitroller = await Unitroller.deploy();
  await unitroller.deployed();
  console.log("Unitroller deployed to:", unitroller.address);

  const Comptroller = await hre.ethers.getContractFactory("Comptroller");
  const comptroller = await Comptroller.deploy();
  await comptroller.deployed();
  console.log("Comptroller deployed to:", comptroller.address);

  let confirmations = hre.network.name === "metis" ? 3 : 1;
  console.log("calling unitroller._setPendingImplementation()");

  let _tx = await unitroller._setPendingImplementation(comptroller.address);
  await _tx.wait(confirmations);

  console.log("calling comptroller._become()");
  _tx = await comptroller._become(unitroller.address);
  await _tx.wait(confirmations);

  const unitrollerProxy = await ethers.getContractAt(
    "Comptroller",
    unitroller.address
  );

  console.log("calling unitrollerProxy._setMaxAssets()");
  _tx = await unitrollerProxy._setMaxAssets(params.maxAssets);
  await _tx.wait(confirmations);

  console.log("calling unitrollerProxy._setCloseFactor()");
  _tx = await unitrollerProxy._setCloseFactor(numToWei(params.closeFactor, 18));
  await _tx.wait(confirmations);

  console.log("calling unitrollerProxy._setLiquidationIncentive()");
  _tx = await unitrollerProxy._setLiquidationIncentive(
    numToWei(params.liquidationIncentive, 18)
  );
  await _tx.wait(confirmations);

  console.log("calling unitrollerProxy._setPriceOracle()");
  _tx = await unitrollerProxy._setPriceOracle(params.oracle);
  await _tx.wait(confirmations);

  // save data
  deployments["Unitroller"] = unitroller.address;
  deployments["Comptroller"] = comptroller.address;
  writeFileSync(outputFilePath, JSON.stringify(deployments, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
