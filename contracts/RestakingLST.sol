// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RestakingLST Token
 * @dev A simplified Liquid Staking Token (LST) for restaking purposes
 */
contract RestakingLST is ERC20 {
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event RewardDistributed(address indexed to, uint256 amount);
    
    // Annual percentage rate for staking rewards (in basis points, e.g., 500 = 5%)
    uint256 public stakingAPR = 500;
    
    // Last time rewards were updated
    uint256 public lastRewardTimestamp;
    
    /**
     * @dev Constructor sets up the RestakingLST token
     * @param name Name of the LST token
     * @param symbol Symbol of the LST token
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        lastRewardTimestamp = block.timestamp;
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
     * @dev Simulates claiming staking rewards
     * @notice This is a simplified version for demonstration purposes
     */
    function claimRewards() external {
        require(balanceOf(msg.sender) > 0, "No staked tokens");
        
        // Calculate time elapsed since last reward
        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
        
        // Only distribute rewards if some time has passed
        if (timeElapsed > 0) {
            // Calculate rewards based on user's balance and APR
            // Formula: balance * (APR/10000) * (timeElapsed/365 days)
            uint256 userBalance = balanceOf(msg.sender);
            uint256 reward = userBalance * stakingAPR * timeElapsed / (10000 * 365 days);
            
            if (reward > 0) {
                _mint(msg.sender, reward);
                emit RewardDistributed(msg.sender, reward);
            }
            
            lastRewardTimestamp = block.timestamp;
        }
    }
    
    /**
     * @dev Updates the staking APR
     * @param newAPR New APR value in basis points (e.g., 500 = 5%)
     * @notice This would typically be restricted to governance or admin
     */
    function updateStakingAPR(uint256 newAPR) external {
        // In a real implementation, this would have access control
        stakingAPR = newAPR;
    }
    
    /**
     * @dev Returns the current APR as a percentage
     * @return The current APR as a percentage (e.g., 5.00 for 5%)
     */
    function getAPRPercentage() external view returns (uint256) {
        return stakingAPR / 100; // Convert basis points to percentage
    }
    
    /**
     * @dev Calculates pending rewards for a user
     * @param user Address of the user
     * @return Pending rewards amount
     */
    function getPendingRewards(address user) external view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
        uint256 userBalance = balanceOf(user);
        
        return userBalance * stakingAPR * timeElapsed / (10000 * 365 days);
    }
    
    /**
     * @dev Returns the number of decimals used by the token
     * @return The number of decimals (18 for most LSTs)
     */
    function decimals() public pure override returns (uint8) {
        return 18; // Standard ERC20 decimals
    }
} 