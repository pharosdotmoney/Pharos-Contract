// scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment process...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);
  
  // Deploy USDC
  console.log("\nDeploying USDC...");
  const USDC = await ethers.getContractFactory("USDC");
  const usdc = await USDC.deploy();
  await usdc.deployed();
  console.log(`USDC deployed to: ${usdc.address}`);
  
  // Deploy RestakingLST
  console.log("\nDeploying RestakingLST...");
  const RestakingLST = await ethers.getContractFactory("RestakingLST");
  const restakingLST = await RestakingLST.deploy("Restaking LST", "rLST");
  await restakingLST.deployed();
  console.log(`RestakingLST deployed to: ${restakingLST.address}`);
  
  // Deploy PUSD
  console.log("\nDeploying PUSD...");
  const PUSD = await ethers.getContractFactory("PUSD");
  const pusd = await PUSD.deploy(usdc.address);
  await pusd.deployed();
  console.log(`PUSD deployed to: ${pusd.address}`);
  
  // Set PUSD address in USDC
  console.log("\nSetting PUSD address in USDC...");
  await usdc.setPusdAddress(pusd.address);
  console.log("PUSD address set in USDC");
  
  // Deploy Eigen (simplified for this example)
  console.log("\nDeploying Eigen...");
  const Eigen = await ethers.getContractFactory("Eigen");
  const eigen = await Eigen.deploy(restakingLST.address);
  await eigen.deployed();
  console.log(`Eigen deployed to: ${eigen.address}`);
  
  // Deploy Operator
  console.log("\nDeploying Operator...");
  const Operator = await ethers.getContractFactory("Operator");
  // Note: We'll update the LoanManager address later
  const operator = await Operator.deploy(ethers.constants.AddressZero, pusd.address);
  await operator.deployed();
  console.log(`Operator deployed to: ${operator.address}`);
  
  // Deploy LoanManager
  console.log("\nDeploying LoanManager...");
  const LoanManager = await ethers.getContractFactory("LoanManager");
  const loanManager = await LoanManager.deploy(eigen.address, pusd.address, operator.address);
  await loanManager.deployed();
  console.log(`LoanManager deployed to: ${loanManager.address}`);
  
  // Update LoanManager address in Operator
  console.log("\nUpdating LoanManager address in Operator...");
  // This requires adding a setLoanManager function to the Operator contract
  await operator.setLoanManager(loanManager.address);
  console.log("LoanManager address updated in Operator");
  
  // Set LoanManager in PUSD
  console.log("\nSetting LoanManager in PUSD...");
  await pusd.setLoanManager(loanManager.address);
  console.log("LoanManager set in PUSD");
  
  // Deploy OperatorRegistry
  console.log("\nDeploying OperatorRegistry...");
  const OperatorRegistry = await ethers.getContractFactory("OperatorRegistry");
  const operatorRegistry = await OperatorRegistry.deploy(deployer.address);
  await operatorRegistry.deployed();
  console.log(`OperatorRegistry deployed to: ${operatorRegistry.address}`);
  
  // Deploy DelegationManager
  console.log("\nDeploying DelegationManager...");
  const DelegationManager = await ethers.getContractFactory("DelegationManager");
  const delegationManager = await DelegationManager.deploy(restakingLST.address, operatorRegistry.address);
  await delegationManager.deployed();
  console.log(`DelegationManager deployed to: ${delegationManager.address}`);
  
  // Deploy LSDT
  console.log("\nDeploying LSDT...");
  const LSDT = await ethers.getContractFactory("LSDT");
  const lsdt = await LSDT.deploy(restakingLST.address, operatorRegistry.address);
  await lsdt.deployed();
  console.log(`LSDT deployed to: ${lsdt.address}`);
  
  // Register the operator in the registry
  console.log("\nRegistering Operator in OperatorRegistry...");
  await operatorRegistry.registerOperator(
    operator.address,
    "Main Operator",
    "https://example.com/operator-metadata"
  );
  console.log("Operator registered in OperatorRegistry");
  
  // Print all deployed contract addresses
  console.log("\n=== Deployed Contract Addresses ===");
  console.log(`USDC: ${usdc.address}`);
  console.log(`RestakingLST: ${restakingLST.address}`);
  console.log(`PUSD: ${pusd.address}`);
  console.log(`Eigen: ${eigen.address}`);
  console.log(`Operator: ${operator.address}`);
  console.log(`LoanManager: ${loanManager.address}`);
  console.log(`OperatorRegistry: ${operatorRegistry.address}`);
  console.log(`DelegationManager: ${delegationManager.address}`);
  console.log(`LSDT: ${lsdt.address}`);
  
  // Save the contract addresses to a file
  const fs = require("fs");
  const contractAddresses = {
    USDC: usdc.address,
    RestakingLST: restakingLST.address,
    PUSD: pusd.address,
    Eigen: eigen.address,
    Operator: operator.address,
    LoanManager: loanManager.address,
    OperatorRegistry: operatorRegistry.address,
    DelegationManager: delegationManager.address,
    LSDT: lsdt.address
  };
  
  fs.writeFileSync("deployed-addresses.json", JSON.stringify(contractAddresses, null, 2));
  console.log("\nContract addresses saved to deployed-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });