// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./OperatorRegistry.sol";
import "./RestakingLST.sol";

/**
 * @title Delegation Manager
 * @dev Contract for delegating LST tokens to operators
 */
contract DelegationManager is ReentrancyGuard {
    RestakingLST public lstToken;
    OperatorRegistry public operatorRegistry;
    
    // Mapping from user address to operator address to delegated amount
    mapping(address => mapping(address => uint256)) public delegations;
    
    // Mapping from user address to total delegated amount
    mapping(address => uint256) public totalUserDelegations;
    
    // Events
    event TokensDelegated(address indexed user, address indexed operator, uint256 amount);
    event DelegationRemoved(address indexed user, address indexed operator, uint256 amount);
    
    /**
     * @dev Constructor sets up the DelegationManager
     * @param _lstToken Address of the LST token contract
     * @param _operatorRegistry Address of the operator registry contract
     */
    constructor(address _lstToken, address _operatorRegistry) {
        require(_lstToken != address(0), "Invalid LST token address");
        require(_operatorRegistry != address(0), "Invalid operator registry address");
        
        lstToken = RestakingLST(_lstToken);
        operatorRegistry = OperatorRegistry(_operatorRegistry);
    }
    
    /**
     * @dev Delegate LST tokens to an operator
     * @param operatorAddress Address of the operator
     * @param amount Amount of LST tokens to delegate
     */
    function delegateToOperator(address operatorAddress, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(operatorRegistry.isActiveOperator(operatorAddress), "Operator not active");
        require(lstToken.balanceOf(msg.sender) >= amount, "Insufficient LST balance");
        
        // Transfer LST tokens from user to this contract
        bool success = lstToken.transferFrom(msg.sender, address(this), amount);
        require(success, "LST transfer failed");
        
        // Update delegation records
        delegations[msg.sender][operatorAddress] += amount;
        totalUserDelegations[msg.sender] += amount;
        
        // Update operator's total delegated amount
        (,uint256 currentDelegated,,,) = operatorRegistry.getOperatorDetails(operatorAddress);
        operatorRegistry.updateDelegation(operatorAddress, currentDelegated + amount);
        
        emit TokensDelegated(msg.sender, operatorAddress, amount);
    }
    
    /**
     * @dev Remove delegation from an operator
     * @param operatorAddress Address of the operator
     * @param amount Amount of LST tokens to undelegate
     */
    function removeDelegation(address operatorAddress, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(delegations[msg.sender][operatorAddress] >= amount, "Insufficient delegated amount");
        
        // Update delegation records
        delegations[msg.sender][operatorAddress] -= amount;
        totalUserDelegations[msg.sender] -= amount;
        
        // Update operator's total delegated amount
        (,uint256 currentDelegated,,,) = operatorRegistry.getOperatorDetails(operatorAddress);
        operatorRegistry.updateDelegation(operatorAddress, currentDelegated - amount);
        
        // Transfer LST tokens back to user
        bool success = lstToken.transfer(msg.sender, amount);
        require(success, "LST transfer failed");
        
        emit DelegationRemoved(msg.sender, operatorAddress, amount);
    }
    
    /**
     * @dev Get the amount delegated by a user to an operator
     * @param user Address of the user
     * @param operatorAddress Address of the operator
     * @return The amount delegated
     */
    function getDelegatedAmount(address user, address operatorAddress) external view returns (uint256) {
        return delegations[user][operatorAddress];
    }
    
    /**
     * @dev Get the total amount delegated by a user
     * @param user Address of the user
     * @return The total amount delegated
     */
    function getTotalDelegatedByUser(address user) external view returns (uint256) {
        return totalUserDelegations[user];
    }
} 