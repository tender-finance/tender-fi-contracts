import hre from "hardhat";

import { readFileSync } from "fs";

const outputFilePath = `./deployments/${hre.network.name}.json`;

// NOTE: we need to set colalteral factors after the price oracle

export async function main() {
    const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));

    const collatoralFactors = {
        [deployments.tMetis]: "900000000000000000" // 90% as an 18 digit number
    }

    const unitrollerAddress: string = deployments.Unitroller;

    const unitrollerProxy = await hre.ethers.getContractAt(
        "Comptroller",
        unitrollerAddress
    );

    let txs = Object.keys(collatoralFactors).map(async (cToken) => {
        console.log(`Calling unitrollerProxy._setCollateralFactor(${cToken}, ${collatoralFactors[cToken]})`)
        let tx = await unitrollerProxy._setCollateralFactor(
            cToken, collatoralFactors[cToken]
        )
        let rc = await tx.wait()
        console.log(rc.events)
    })
    await Promise.all(txs)

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
