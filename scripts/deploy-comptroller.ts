import hre from "hardhat";
import { readFileSync, writeFileSync } from "fs";

const outputFilePath = `./deployments/${hre.network.name}.json`;
import { Unitroller__factory } from "../typechain";

const Unitroller_Add = "0x3fe29D7412aCDade27e21f55a65a7ddcCE23d9B3";

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));
  const Comptroller = await hre.ethers.getContractFactory("Comptroller");
  const comptroller = await Comptroller.deploy();
  await comptroller.deployed();
  console.log("Comptroller deployed to:", comptroller.address);

  console.log("calling unitroller._setPendingImplementation()");
  const Unitroller = Unitroller__factory.connect(Unitroller_Add, deployer);

  let _tx = await Unitroller._setPendingImplementation(comptroller.address);
  console.log(`Tx: ${_tx.hash}`);
  await _tx.wait(3);

  console.log("calling comptroller._become()");
  _tx = await comptroller._become(Unitroller_Add);
  await _tx.wait(3);

  // save data
  deployments["Comptroller"] = comptroller.address;
  writeFileSync(outputFilePath, JSON.stringify(deployments, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });