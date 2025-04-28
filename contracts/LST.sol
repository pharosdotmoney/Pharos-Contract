// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Eigen.sol";

/**
 * @title RestakingLST Token
 * @dev A simplified Liquid Staking Token (LST) for restaking purposes
 */
contract LST is ERC20, Ownable {
    Eigen public eigen;
    
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
    
    /**
     * @dev Returns the number of decimals used by the token
     * @return The number of decimals (18 for most LSTs)
     */
    function decimals() public pure override returns (uint8) {
        return 18; // Standard ERC20 decimals
    }

    // This call would be made from eigen contract to transfer lst tokens from account addresss to eigen contract address
    function transferToEigen(address account, uint256 amount) external {
        require(msg.sender == address(eigen), "Only eigen contract can call this function");
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(account) >= amount, "Insufficient balance");
        _transfer(account, address(eigen), amount);
    }

} 