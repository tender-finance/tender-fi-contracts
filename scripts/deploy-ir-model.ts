import hre from "hardhat";
import { readFileSync, writeFileSync } from "fs";
import { numToWei } from "../utils/ethUnitParser";
import { toBn } from "../utils/bn";

const outputFilePath = `./deployments/${hre.network.name}.json`;

// IR Model Params
const params = {
  baseRate: "2",
  multiplier: "20",
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));

  const baseRate = numToWei(toBn(params.baseRate).div(100), 18);
  const multiplier = numToWei(toBn(params.multiplier).div(100), 18);
  const WhitePaperInterestRateModel = await hre.ethers.getContractFactory("WhitePaperInterestRateModel");
  const whitePaperInterestRateModel = await WhitePaperInterestRateModel.deploy(baseRate, multiplier);
  await whitePaperInterestRateModel.deployed();
  console.log("WhitePaperInterestRateModel deployed to:", whitePaperInterestRateModel.address);

  // save data
  if (!deployments["IRModels"]) deployments["IRModels"] = {};
  deployments["IRModels"][`${params.baseRate}__${params.multiplier}`] = whitePaperInterestRateModel.address;
  writeFileSync(outputFilePath, JSON.stringify(deployments, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });