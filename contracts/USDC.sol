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
    event TransferredToPUSD(address indexed from, uint256 amount);
    
    // PUSD contract address
    address public pusdAddress;
    address public operatorAddress;
    
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

    function setOperatorAddress(address _operatorAddress) external onlyOwner {
        require(_operatorAddress != address(0), "Operator address cannot be zero");
        operatorAddress = _operatorAddress;
    }
    
    /**
     * @dev Transfers PUSD tokens from one address to another
     * @param from Address to transfer from
     * @param amount Amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferToPusd(address from, uint256 amount) external returns (bool) {
        require(msg.sender == pusdAddress, "Only PUSD contract can call this function");
        require(pusdAddress != address(0), "PUSD address not set");
        require(from != address(0), "Cannot transfer from zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(from) >= amount, "Insufficient balance");
        // transfer from from address to pusd contract address
        _transfer(from, pusdAddress, amount);
        emit TransferredToPUSD(from, amount);
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

    function mintToOperator(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        _mint(operatorAddress, amount);
    }
}

//mint , burn call transfer from