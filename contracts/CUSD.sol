// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CUSD Stablecoin
 * @dev A stablecoin that is backed 1:1 by USDC deposits
 */
contract CUSD is ERC20, Ownable, ReentrancyGuard {
    IERC20 public usdc;
    
    // Events
    event Deposit(address indexed user, uint256 usdcAmount, uint256 cusdAmount);
    event Withdraw(address indexed user, uint256 cusdAmount, uint256 usdcAmount);
    
    /**
     * @dev Constructor sets up the CUSD token and links to the USDC contract
     * @param _usdc Address of the USDC token contract
     * @param initialOwner Address of the contract owner
     */
    constructor(address _usdc, address initialOwner) 
        ERC20("CUSD Stablecoin", "CUSD") 
        Ownable(initialOwner) 
    {
        require(_usdc != address(0), "USDC address cannot be zero");
        usdc = IERC20(_usdc);
    }
    
    /**
     * @dev Allows users to deposit USDC and mint CUSD at a 1:1 ratio
     * @param usdcAmount Amount of USDC to deposit
     */
    function deposit(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > 0, "Deposit amount must be greater than zero");
        
        // Transfer USDC from user to this contract
        bool success = usdc.transferFrom(msg.sender, address(this), usdcAmount);
        require(success, "USDC transfer failed");
        
        // Mint equivalent amount of CUSD to the user
        _mint(msg.sender, usdcAmount);
        
        emit Deposit(msg.sender, usdcAmount, usdcAmount);
    }
    
    /**
     * @dev Allows users to burn CUSD and withdraw USDC at a 1:1 ratio
     * @param cusdAmount Amount of CUSD to burn
     */
    function withdraw(uint256 cusdAmount) external nonReentrant {
        require(cusdAmount > 0, "Withdraw amount must be greater than zero");
        require(balanceOf(msg.sender) >= cusdAmount, "Insufficient CUSD balance");
        
        // Burn CUSD from the user
        _burn(msg.sender, cusdAmount);
        
        // Transfer equivalent amount of USDC to the user
        bool success = usdc.transfer(msg.sender, cusdAmount);
        require(success, "USDC transfer failed");
        
        emit Withdraw(msg.sender, cusdAmount, cusdAmount);
    }
    
    /**
     * @dev Returns the total USDC held by this contract
     * @return Total USDC balance
     */
    function getReserves() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
    
    /**
     * @dev Emergency function to recover tokens accidentally sent to the contract
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     * @notice This function can only be called by the owner
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(usdc), "Cannot recover the reserve token");
        IERC20(token).transfer(owner(), amount);
    }
} 