import hre from "hardhat";
import { writeFileSync } from "fs";

import { main as DeployMockOracle } from "./deploy-mock-price-oracle";
import { main as DeployProtocol } from "./deploy-protocol";
import { main as DeployLens } from "./deploy-lens";
import { main as DeployIrModel } from "./deploy-ir-model";
import { main as DeployJumpModel } from "./deploy-jumprate-model";
import { main as DeployCToken } from "./deploy-ctoken";
import { main as SetMockOraclePrice } from "./set-mock-oracle-price";
import { main as SetCollateralFactor } from "./set-cf"
const outputFilePath = `./deployments/${hre.network.name}.json`;

const adminWallet = process.env.PUBLIC_KEY

if (adminWallet === undefined) {
  console.error("Please define your PUBLIC_KEY in .env");
  process.exit(1);
}

async function main() {
  // Reset the deployment address file
  writeFileSync(outputFilePath, JSON.stringify({}));

  // Need oracle deployed first to set on unitroller in DeployProtocol
  await DeployMockOracle();

  await DeployProtocol();
  await DeployLens();
  await DeployIrModel();
  await DeployJumpModel(adminWallet);

  // Depends on previous deployments
  await DeployCToken();

  await SetMockOraclePrice();

  // SetCollateralFactor requires the price to be set first
  await SetCollateralFactor()
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
