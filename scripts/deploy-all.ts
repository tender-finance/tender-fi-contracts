import hre from "hardhat";
import { writeFileSync } from "fs";

import { main as DeployProtocol } from "./deploy-protocol";
import { main as DeployLens } from "./deploy-lens";
import { main as DeployIrModel } from "./deploy-ir-model";
import { main as DeployJumpModel } from "./deploy-jumprate-model";
import { main as DeployCToken } from "./deploy-ctoken";

const outputFilePath = `./deployments/${hre.network.name}.json`;

const adminWallet = "0x5B33EC561Cb20EaF7d5b41A9B68A690E2EBBc893";

async function main() {
  // Reset the deployment address file
  writeFileSync(outputFilePath, JSON.stringify({}));

  await DeployProtocol();
  await DeployLens();
  await DeployIrModel();
  await DeployJumpModel(adminWallet);

  // Depends on previous deployments
  await DeployCToken();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
