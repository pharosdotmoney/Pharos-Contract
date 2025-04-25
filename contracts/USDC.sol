// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title USDC Token
 * @dev A simplified USDC token where anyone can mint tokens
 */
contract USDC is ERC20 {
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    
    /**
     * @dev Constructor sets up the USDC token
     */
    constructor() ERC20("USD Coin", "USDC") {}
    
    /**
     * @dev Allows anyone to mint USDC tokens
     * @param amount Amount of tokens to mint
     */
    function mint(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        
        _mint(msg.sender, amount);
        
        emit TokensMinted(msg.sender, amount);
    }
    
    /**
     * @dev Returns the number of decimals used by the token
     * @return The number of decimals (6 for USDC)
     */
    function decimals() public pure override returns (uint8) {
        return 6; // USDC uses 6 decimals
    }
}

//mint , burn call transfer from