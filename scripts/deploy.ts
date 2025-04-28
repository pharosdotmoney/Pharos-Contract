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

  // Set PUSD address in USDC
  console.log("\nSetting PUSD address in USDC...");
  await usdc.setPusdAddress(await pusd.getAddress());
  console.log("PUSD address set in USDC");

  // Deploy Operator first (since Eigen needs it)
  console.log("\nDeploying Operator...");
  const Operator = await ethers.getContractFactory("Operator");
  const operator = await Operator.deploy();
  await operator.waitForDeployment();
  console.log(`Operator deployed to: ${await operator.getAddress()}`);

  // Set Operator address in USDC
  console.log("\nSetting Operator address in USDC...");
  await usdc.setOperatorAddress(await operator.getAddress());
  console.log("Operator address set in USDC");

  // Set PUSD in Operator
  console.log("\nSetting PUSD in Operator...");
  await operator.setPUSD(await pusd.getAddress());
  console.log("PUSD set in Operator");

  // Deploy Eigen with both required parameters
  console.log("\nDeploying Eigen...");
  const Eigen = await ethers.getContractFactory("Eigen");
  const eigen = await Eigen.deploy(
    await lst.getAddress(),
    await operator.getAddress()
  );
  await eigen.waitForDeployment();
  console.log(`Eigen deployed to: ${await eigen.getAddress()}`);

  // Set Eigen in Operator
  console.log("\nSetting Eigen in Operator...");
  await operator.setEigen(await eigen.getAddress());
  console.log("Eigen set in Operator");

  // Set Eigen address in LST
  console.log("\nSetting Eigen address in LST...");
  await lst.setEigenAddress(await eigen.getAddress());
  console.log("Eigen address set in LST");

  // Deploy LoanManager
  console.log("\nDeploying LoanManager...");
  const LoanManager = await ethers.getContractFactory("LoanManager");
  const loanManager = await LoanManager.deploy(
    await eigen.getAddress(),
    await pusd.getAddress(),
    await operator.getAddress()
  );
  await loanManager.waitForDeployment();
  console.log(`LoanManager deployed to: ${await loanManager.getAddress()}`);

  // Update LoanManager address in Operator
  console.log("\nUpdating LoanManager address in Operator...");
  await operator.setLoanManager(await loanManager.getAddress());
  console.log("LoanManager address updated in Operator");

  // Set LoanManager in PUSD
  console.log("\nSetting LoanManager in PUSD...");
  await pusd.setLoanManager(await loanManager.getAddress());
  console.log("LoanManager set in PUSD");

  // Print all deployed contract addresses
  console.log("\n=== Deployed Contract Addresses ===");
  console.log(`USDC: ${await usdc.getAddress()}`);
  console.log(`LST: ${await lst.getAddress()}`);
  console.log(`PUSD: ${await pusd.getAddress()}`);
  console.log(`Operator: ${await operator.getAddress()}`);
  console.log(`Eigen: ${await eigen.getAddress()}`);
  console.log(`LoanManager: ${await loanManager.getAddress()}`);

  // Save the contract addresses to a file
  const fs = require("fs");
  const contractAddresses = {
    USDC: await usdc.getAddress(),
    LST: await lst.getAddress(),
    PUSD: await pusd.getAddress(),
    PUSDC: await pusd.getAddress(),
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
