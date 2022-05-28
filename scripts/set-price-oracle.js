var hre = require("hardhat");
var { readFileSync, writeFileSync } = require("fs");

const outputFilePath = `./deployments/${hre.network.name}.json`;

const PRICE_ORACLE = "0x973f9ce86Dc11159CE00E9a715CC8142D7bE82cC"
// Sets this to be the price oracle, and writes it to the json file

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

    const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));

    const unitrollerProxy = await hre.ethers.getContractAt(
        "Comptroller",
        deployments.Unitroller
    );

    console.log("calling unitrollerProxy._setPriceOracle()");

    await unitrollerProxy._setPriceOracle(PRICE_ORACLE);

    // Save to output
    deployments["PRICE_ORACLE"] = PRICE_ORACLE
    writeFileSync(outputFilePath, JSON.stringify(deployments, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
