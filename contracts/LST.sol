// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Eigen.sol";
import "./USDC.sol";
import "./PUSD.sol";

/**
 * @title RestakingLST Token
 * @dev A simplified Liquid Staking Token (LST) for restaking purposes
 */
contract LST is ERC20, Ownable {
    Eigen public eigen;
    USDC public usdc;
    PUSD public pusd;
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    
    /**
     * @dev Constructor sets up the RestakingLST token
     * @param name Name of the LST token
     * @param symbol Symbol of the LST token
     */
    constructor(string memory name, string memory symbol) ERC20("Liquid Staking Token", "LST") Ownable(msg.sender) {
    }

    function setUSDCAddress(address _usdcAddress) external onlyOwner {
        usdc = USDC(_usdcAddress);
    }

    function setPUSDAddress(address _pusdAddress) external onlyOwner {
        pusd = PUSD(_pusdAddress);
    }

    function setEigenAddress(address _eigenAddress) external onlyOwner {
        eigen = Eigen(_eigenAddress);
    }
    
    /**
     * @dev Allows anyone to mint LST tokens (simulating staking)
     * @param amount Amount of tokens to mint
     */
    function mint(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        
        _mint(msg.sender, amount);
        
        emit TokensMinted(msg.sender, amount);
    }

    /**
     * @dev Allows anyone to burn LST tokens (simulating unstaking)
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _burn(msg.sender, amount);
        
        emit TokensBurned(msg.sender, amount);
    }
    // This call would be made from eigen contract to transfer lst tokens from account addresss to eigen contract address
    function transferToEigen(address account, uint256 amount) external {
        require(msg.sender == address(eigen), "Only eigen contract can call this function");
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(account) >= amount, "Insufficient balance");
        _transfer(account, address(eigen), amount);
    }

    // require caller to be eigen contract
    function convertToUSDCAndSendToPUSD(uint256 amount) external {
        require(msg.sender == address(eigen), "Only eigen contract can call this function");
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(address(pusd) != address(0), "PUSD contract not set");
        require(address(usdc) != address(0), "USDC contract not set");
        
        // Burn the LST tokens from the eigen contract
        _burn(msg.sender, amount);
        
        // Convert to USDC and send to PUSD
        bool success = pusd.mintPusdAndTransferToSPUSD(amount);
        require(success, "PUSD conversion failed");
    }
    
    /**
     * @dev Returns the number of decimals used by the token
     * @return The number of decimals (18 for most LSTs)
     */
    function decimals() public pure override returns (uint8) {
        return 18; // Standard ERC20 decimals
    }

} 