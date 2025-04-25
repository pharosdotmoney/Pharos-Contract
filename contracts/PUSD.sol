// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PUSD Stablecoin
 * @dev A stablecoin that is backed 1:1 by USDC deposits
 */
contract PUSD is ERC20, Ownable, ReentrancyGuard {
    IERC20 public usdc;
    
    // Mapping to track user deposits
    mapping(address => uint256) private userDeposits;
    
    // Events
    event Deposit(address indexed user, uint256 usdcAmount, uint256 pusdAmount);
    event Withdraw(address indexed user, uint256 pusdAmount, uint256 usdcAmount);
    event Mint(address indexed user, uint256 pusdAmount);
    
    /**
     * @dev Constructor sets up the PUSD token and links to the USDC contract
     * @param _usdc Address of the USDC token contract
     * @param initialOwner Address of the contract owner
     */
    constructor(address _usdc, address initialOwner) 
        ERC20("PUSD Stablecoin", "PUSD") 
        Ownable(initialOwner) 
    {
        require(_usdc != address(0), "USDC address cannot be zero");
        usdc = IERC20(_usdc);
    }
    
    /**
     * @dev Allows users to deposit USDC and mint PUSD at a 1:1 ratio
     * @param usdcAmount Amount of USDC to deposit
     * @notice When depositing USDC, the user's USDC balance decreases and their PUSD balance increases
     */
    function deposit(uint256 usdcAmount) external nonReentrant {
        require(usdcAmount > 0, "Deposit amount must be greater than zero");
        
        // Transfer USDC from user to this contract (decreases user's USDC balance)
        bool success = usdc.transferFrom(msg.sender, address(this), usdcAmount);
        require(success, "USDC transfer failed");
        
        // Update user's deposit record
        userDeposits[msg.sender] += usdcAmount;
        
        // Mint equivalent amount of PUSD to the user (increases user's PUSD balance)
        _mint(msg.sender, usdcAmount);
        
        emit Deposit(msg.sender, usdcAmount, usdcAmount);
    }
    
    /**
     * @dev Allows users to burn PUSD and withdraw USDC at a 1:1 ratio
     * @param pusdAmount Amount of PUSD to burn
     * @notice When withdrawing, the user's PUSD balance decreases and their USDC balance increases
     */
    function withdraw(uint256 pusdAmount) external nonReentrant {
        require(pusdAmount > 0, "Withdraw amount must be greater than zero");
        require(balanceOf(msg.sender) >= pusdAmount, "Insufficient PUSD balance");
        
        // Update user's deposit record
        if (userDeposits[msg.sender] >= pusdAmount) {
            userDeposits[msg.sender] -= pusdAmount;
        } else {
            userDeposits[msg.sender] = 0;
        }
        
        // Burn PUSD from the user (decreases user's PUSD balance)
        _burn(msg.sender, pusdAmount);
        
        // Transfer equivalent amount of USDC to the user (increases user's USDC balance)
        bool success = usdc.transfer(msg.sender, pusdAmount);
        require(success, "USDC transfer failed");
        
        emit Withdraw(msg.sender, pusdAmount, pusdAmount);
    }
    
    /**
     * @dev Allows direct minting of PUSD without USDC deposit (for authorized users)
     * @param pusdAmount Amount of PUSD to mint
     * @notice This increases the recipient's PUSD balance without affecting USDC
     */
    function mint(uint256 pusdAmount) external onlyOwner nonReentrant {
        require(pusdAmount > 0, "Mint amount must be greater than zero");
        
        // Mint PUSD to the user (increases user's PUSD balance)
        _mint(msg.sender, pusdAmount);
        
        emit Mint(msg.sender, pusdAmount);
    }
    
    /**
     * @dev Returns the PUSD balance of a user
     * @param user Address of the user
     * @return The PUSD balance of the user
     */
    function getPUSDBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }
    
    /**
     * @dev Returns the USDC balance of a user
     * @param user Address of the user
     * @return The USDC balance of the user
     */
    function getUSDCBalance(address user) external view returns (uint256) {
        return usdc.balanceOf(user);
    }
    
    /**
     * @dev Returns the total amount of USDC deposited by a user
     * @param user Address of the user
     * @return The total USDC deposited by the user
     */
    function getUserDeposits(address user) external view returns (uint256) {
        return userDeposits[user];
    }
    
    /**
     * @dev Returns a summary of a user's balances and deposits
     * @param user Address of the user
     * @return pusdBalance The user's PUSD balance
     * @return usdcBalance The user's USDC balance
     * @return totalDeposited The total USDC deposited by the user
     */
    function getUserBalanceSummary(address user) external view returns (
        uint256 pusdBalance,
        uint256 usdcBalance,
        uint256 totalDeposited
    ) {
        return (
            balanceOf(user),
            usdc.balanceOf(user),
            userDeposits[user]
        );
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

//usdc ka tranfer from call hoga 

// increase balance of pusd

// burn fn opposite

// operator screen contract 