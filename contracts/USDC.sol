// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title USDC Token
 * @dev A simplified USDC token where anyone can mint tokens
 */
contract USDC is ERC20, Ownable {
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event PUSDAddressSet(address indexed pusdAddress);
    event TransferredFromPUSD(address indexed from, address indexed to, uint256 amount);
    
    // PUSD contract address
    address public pusdAddress;
    
    /**
     * @dev Constructor sets up the USDC token
     */
    constructor() ERC20("USD Coin", "USDC") Ownable(msg.sender) {}
    
    /**
     * @dev Sets the address of the PUSD contract
     * @param _pusdAddress Address of the PUSD contract
     */
    function setPusdAddress(address _pusdAddress) external onlyOwner {
        require(_pusdAddress != address(0), "PUSD address cannot be zero");
        pusdAddress = _pusdAddress;
        emit PUSDAddressSet(_pusdAddress);
    }
    
    /**
     * @dev Transfers PUSD tokens from one address to another
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param amount Amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFromPusd(address from, address to, uint256 amount) external returns (bool) {
        require(pusdAddress != address(0), "PUSD address not set");
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than zero");
        
        // Call transferFrom on the PUSD contract
        bool success = IERC20(pusdAddress).transferFrom(from, to, amount);
        require(success, "PUSD transfer failed");
        
        emit TransferredFromPUSD(from, to, amount);
        return true;
    }
    
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
     * @dev Burns USDC tokens from the caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
        
        _burn(msg.sender, amount);
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