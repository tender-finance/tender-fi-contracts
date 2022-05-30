import hre, { ethers } from "hardhat";

import { readFileSync } from "fs";

const outputFilePath = `./deployments/${hre.network.name}.json`;

// NOTE: we need to set collateral factors after the price oracle

export async function main() {
  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));

  const collatoralFactors = {
    [deployments.tMetis]: ethers.utils.parseUnits("9", 17), // 90% as an 18 digit number
    [deployments.bMetis]: ethers.utils.parseUnits("7", 17), // 70% as an 18 digit number
    [deployments.kMetis]: ethers.utils.parseUnits("1", 17), // 10% as an 18 digit number
  };

  const unitrollerAddress: string = deployments.Unitroller;

  const unitrollerProxy = await hre.ethers.getContractAt(
    "Comptroller",
    unitrollerAddress
  );

  for (let address in collatoralFactors) {
    console.log(
      `Calling unitrollerProxy._setCollateralFactor(${address}, ${collatoralFactors[address]})`
    );

    let tx = await unitrollerProxy._setCollateralFactor(
      address,
      collatoralFactors[address]
    );
    let rc = await tx.wait();
    console.log(rc.events);
  }
}

// main()
//     .then(() => process.exit(0))
//     .catch((error) => {
//         console.error(error);
//         process.exit(1);
//     });
