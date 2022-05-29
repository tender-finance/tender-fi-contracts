import hre from "hardhat";
import { writeFileSync } from "fs";

import { main as DeployMockOracle } from "./deploy-mock-price-oracle";
import { main as DeployProtocol } from "./deploy-protocol";
import { main as DeployLens } from "./deploy-lens";
import { main as DeployIrModel } from "./deploy-ir-model";
import { main as DeployJumpModel } from "./deploy-jumprate-model";
import { main as DeployCToken } from "./deploy-ctoken";
import { main as SetMockOraclePrice } from "./set-mock-oracle-price";

const outputFilePath = `./deployments/${hre.network.name}.json`;

const adminWallet = "0x51129c8332A220E0bF9546A6Fe07481c17D2B638";

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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
