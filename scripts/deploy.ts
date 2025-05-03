// scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment process...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(
    `Account balance: ${(
      await ethers.provider.getBalance(deployer.address)
    ).toString()}`
  );

  // Deploy USDC
  console.log("\nDeploying USDC...");
  const USDC = await ethers.getContractFactory("USDC");
  const usdc = await USDC.deploy();
  await usdc.waitForDeployment();
  console.log(`USDC deployed to: ${await usdc.getAddress()}`);

  // Deploy LST
  console.log("\nDeploying LST...");
  const LST = await ethers.getContractFactory("LST");
  const lst = await LST.deploy("Liquid Staking Token", "LST");
  await lst.waitForDeployment();
  console.log(`LST deployed to: ${await lst.getAddress()}`);

  // Deploy PUSD
  console.log("\nDeploying PUSD...");
  const PUSD = await ethers.getContractFactory("PUSD");
  const pusd = await PUSD.deploy(await usdc.getAddress());
  await pusd.waitForDeployment();
  console.log(`PUSD deployed to: ${await pusd.getAddress()}`);

  // Deploy sPUSD
  console.log("\nDeploying sPUSD...");
  const sPUSD = await ethers.getContractFactory("sPUSD");
  const spusd = await sPUSD.deploy(await pusd.getAddress());
  await spusd.waitForDeployment();
  console.log(`sPUSD deployed to: ${await spusd.getAddress()}`);

  // Deploy Operator first (since Eigen needs it)
  console.log("\nDeploying Operator...");
  const Operator = await ethers.getContractFactory("Operator");
  const operator = await Operator.deploy();
  await operator.waitForDeployment();
  console.log(`Operator deployed to: ${await operator.getAddress()}`);

  // Set operator address in PUSD
  console.log("\nSetting operator address in PUSD...");
  await pusd.setOperatorAddress(await operator.getAddress());
  console.log("Operator address set in PUSD");

  // Deploy Eigen with both required parameters
  console.log("\nDeploying Eigen...");
  const Eigen = await ethers.getContractFactory("Eigen");
  const eigen = await Eigen.deploy(
    await lst.getAddress(),
    await operator.getAddress()
  );
  await eigen.waitForDeployment();
  console.log(`Eigen deployed to: ${await eigen.getAddress()}`);

  // Deploy LoanManager
  console.log("\nDeploying LoanManager...");
  const LoanManager = await ethers.getContractFactory("LoanManager");
  const loanManager = await LoanManager.deploy(
    await eigen.getAddress(),
    await spusd.getAddress(),
    await operator.getAddress()
  );
  await loanManager.waitForDeployment();
  console.log(`LoanManager deployed to: ${await loanManager.getAddress()}`);

  // Now set up all the required addresses in the correct order
  // Set PUSD token address in LoanManager
  console.log("\nSetting PUSD token address in LoanManager...");
  await loanManager.setPUSDToken(await pusd.getAddress());
  console.log("PUSD token address set in LoanManager");

  // Set USDC addresses
  console.log("\nSetting addresses in USDC...");
  await usdc.setPusdAddress(await pusd.getAddress());
  await usdc.setOperatorAddress(await operator.getAddress());
  console.log("USDC addresses set");

  // Set LST addresses
  console.log("\nSetting addresses in LST...");
  await lst.setUSDCAddress(await usdc.getAddress());
  await lst.setEigenAddress(await eigen.getAddress());
  await lst.setPUSDAddress(await pusd.getAddress());
  console.log("LST addresses set");

  // Set PUSD addresses
  console.log("\nSetting addresses in PUSD...");
  await pusd.setLoanManager(await loanManager.getAddress());
  await pusd.setsPUSDAddress(await spusd.getAddress());
  console.log("PUSD addresses set");

  // Set sPUSD addresses
  console.log("\nSetting addresses in sPUSD...");
  await spusd.setLoanManager(await loanManager.getAddress());
  console.log("sPUSD addresses set");

  // Set Operator addresses
  console.log("\nSetting addresses in Operator...");
  await operator.setPUSD(await pusd.getAddress());
  await operator.setEigen(await eigen.getAddress());
  await operator.setLoanManager(await loanManager.getAddress());
  console.log("Operator addresses set");

  // Print all deployed contract addresses
  console.log("\n=== Deployed Contract Addresses ===");
  console.log(`USDC: ${await usdc.getAddress()}`);
  console.log(`LST: ${await lst.getAddress()}`);
  console.log(`PUSD: ${await pusd.getAddress()}`);
  console.log(`sPUSD: ${await spusd.getAddress()}`);
  console.log(`Operator: ${await operator.getAddress()}`);
  console.log(`Eigen: ${await eigen.getAddress()}`);
  console.log(`LoanManager: ${await loanManager.getAddress()}`);

  // Save the contract addresses to a file
  const fs = require("fs");
  const contractAddresses = {
    USDC: await usdc.getAddress(),
    LST: await lst.getAddress(),
    PUSD: await pusd.getAddress(),
    sPUSD: await spusd.getAddress(),
    Operator: await operator.getAddress(),
    Eigen: await eigen.getAddress(),
    LoanManager: await loanManager.getAddress(),
  };

  fs.writeFileSync(
    "deployed-addresses.json",
    JSON.stringify(contractAddresses, null, 2)
  );
  console.log("\nContract addresses saved to deployed-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
