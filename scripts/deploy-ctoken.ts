import hre from "hardhat";
import { numToWei } from "../utils/ethUnitParser";

import { readFileSync, writeFileSync } from "fs";
import { ethers } from "ethers";

const outputFilePath = `./deployments/${hre.network.name}.json`;

const CTOKEN_DECIMALS = 8;

export const CTOKENS = [
  {
    underlying: "0x5197487406336229a37D724710380278A1dca6b2",
    name: "tTestDAI",
    symbol: "tTestDAI",
    decimals: CTOKEN_DECIMALS,
    collateralFactor: ethers.utils.parseUnits("9", 17),
    priceInUsd: "1",
  },
  {
    underlying: "0xaD26Cc863cb1aaba691469246B4B4D65D951188e",
    name: "tTestETH",
    symbol: "tTestETH",
    decimals: CTOKEN_DECIMALS,
    collateralFactor: ethers.utils.parseUnits("7", 17),
    priceInUsd: "1800",
  },
  {
    underlying: "0xAE745689b84ed533580610504Fe4baf38BEfc2C8",
    name: "tTestWBTC",
    symbol: "tTestWBTC",
    decimals: CTOKEN_DECIMALS,
    collateralFactor: ethers.utils.parseUnits("1", 17),
    priceInUsd: "29000",
  },
];

export async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`>>>>>>>>>>>> Deployer: ${deployer.address} <<<<<<<<<<<<\n`);

  const CErc20Immutable = await hre.ethers.getContractFactory(
    "CErc20Immutable"
  );

  const deployments = JSON.parse(readFileSync(outputFilePath, "utf-8"));
  // const comptrollerAddress: string = deployments.Comptroller;
  const unitrollerAddress: string = deployments.Unitroller;
  // TODO: This is fragile if the parameters change
  const irModelAddress: string =
    deployments.IRModels.WhitePaperInterestRateModel["6000000"]["0__1500"];

  for (let i = 0; i < CTOKENS.length; i++) {
    let token = CTOKENS[i];

    const erc20Underlying = await hre.ethers.getContractAt(
      "EIP20Interface",
      token.underlying
    );
    const underlyingDecimals = await erc20Underlying.decimals();
    const totalDecimals = underlyingDecimals + token.decimals;
    const initialExcRateMantissaStr = numToWei("2", totalDecimals);

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
  }
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
