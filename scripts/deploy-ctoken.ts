import hre from "hardhat";
import { numToWei } from "../utils/ethUnitParser";

import { readFileSync, writeFileSync } from "fs";

const outputFilePath = `./deployments/${hre.network.name}.json`;

const CTOKEN_DECIMALS = 8;

// CToken Params
// const params = {
//   underlying: "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
//   name: "tMetis",
//   symbol: "tMetis",
//   decimals: CTOKEN_DECIMALS,
// };

export async function main() {
  const d = [
    {
      underlying: "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
      name: "tMetis",
      symbol: "tMetis",
      decimals: CTOKEN_DECIMALS,
    },
    {
      underlying: "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
      name: "bMetis",
      symbol: "bMetis",
      decimals: CTOKEN_DECIMALS,
    },
    {
      underlying: "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
      name: "kMetis",
      symbol: "kMetis",
      decimals: CTOKEN_DECIMALS,
    },
  ];

  let p = d[0];

  const [deployer] = await hre.ethers.getSigners();
  console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

  const erc20Underlying = await hre.ethers.getContractAt(
    "EIP20Interface",
    p.underlying
  );
  const underlyingDecimals = await erc20Underlying.decimals();
  const totalDecimals = underlyingDecimals + p.decimals;
  const initialExcRateMantissaStr = numToWei("2", totalDecimals);

  const CErc20Immutable = await hre.ethers.getContractFactory(
    "CErc20Immutable"
  );

  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));
  // const comptrollerAddress: string = deployments.Comptroller;
  const unitrollerAddress: string = deployments.Unitroller;
  // TODO: This is fragile if the parameters change
  const irModelAddress: string =
    deployments.IRModels.WhitePaperInterestRateModel["6000000"]["0__1500"];

  let tokens = d.forEach(async (token) => {
    const cErc20Immutable = await CErc20Immutable.deploy(
      token.underlying,
      unitrollerAddress,
      irModelAddress,
      initialExcRateMantissaStr,
      token.name,
      token.symbol,
      token.decimals,
      deployer.address
    );
    await cErc20Immutable.deployed();
    console.log("CErc20Immutable deployed to:", cErc20Immutable.address);

    const unitrollerProxy = await hre.ethers.getContractAt(
      "Comptroller",
      unitrollerAddress
    );

    console.log("calling unitrollerProxy._supportMarket()");

    await unitrollerProxy._supportMarket(cErc20Immutable.address);

    let confirmations = hre.network.name === "metis" ? 15 : 1;
    await cErc20Immutable.deployTransaction.wait(confirmations);

    // Save to output
    deployments[token.symbol] = cErc20Immutable.address;
    writeFileSync(outputFilePath, JSON.stringify(deployments, null, 2));

    try {
      await verifyContract(cErc20Immutable.address, [
        token.underlying,
        unitrollerAddress,
        irModelAddress,
        initialExcRateMantissaStr,
        token.name,
        token.symbol,
        token.decimals,
        deployer.address,
      ]);
    } catch (e) {
      console.error("Error verifying cErc20Immutable", cErc20Immutable.address);
      console.error(e);
    }
  });

  // await Promise.all(tokens);
}

const verifyContract = async (
  contractAddress: string,
  constructorArgs: any
) => {
  await hre.run("verify:verify", {
    contract: "contracts/CErc20Immutable.sol:CErc20Immutable",
    address: contractAddress,
    constructorArguments: constructorArgs,
  });
};

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
