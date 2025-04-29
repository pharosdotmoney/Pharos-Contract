// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LST.sol";
import "./IOperator.sol";

/**
 * @title Eigen
 * @dev Contract for tracking Eigen token delegations from restakers to operators
 * Simplified version which only tracks a single operator and a single lst token
 */
contract Eigen is Ownable {
    // Reference to the LST token contract
    LST public lst;
    IOperator public operator;

    
    // Mapping: restaker address => delegated amount
    mapping(address => uint256) public delegations;
    
    // Array to track all addresses that have delegations
    address[] public delegators;
    
    // Mapping to track if an address is in the delegators array
    mapping(address => bool) public isDelegator;
    
    // Total delegated LST tokens across all restakers and operators
    uint256 public totalDelegatedTokens;
    
    // Events
    event DelegationAdded(address indexed restaker, uint256 amount);
    event DelegationRemoved(address indexed restaker, uint256 amount);
    
    /**
     * @dev Constructor sets up the LSDT contract
     * @param _lstToken Address of the LST token contract
     * @param _operator Address of the operator
     */
    constructor(address _lstToken, address _operator) Ownable(msg.sender) {
        require(_lstToken != address(0), "LST token address cannot be zero");
        require(_operator != address(0), "Operator address cannot be zero");
        
        lst = LST(_lstToken);
        operator = IOperator(_operator);
    }
    
    /**
     * @dev Add a delegation record
     * @param amount Amount of LST tokens delegated
     */
    function addDelegation(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(lst.balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Transfer LST tokens from msg.sender to eigen contract address
        lst.transferToEigen(msg.sender, amount);

        // Update delegation records
        if (delegations[msg.sender] == 0) {
            // First time delegating, add to delegators array
            if (!isDelegator[msg.sender]) {
                delegators.push(msg.sender);
                isDelegator[msg.sender] = true;
            }
        }
        
        delegations[msg.sender] += amount;
        totalDelegatedTokens += amount;
        emit DelegationAdded(msg.sender, amount);
    }
    
    /**
     * @dev Remove a delegation record
     * @param amount Amount of LST tokens to undelegate
     */
    function removeDelegation(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(delegations[msg.sender] >= amount, "Insufficient delegated amount");
        // send LST tokens from eigen contract address to msg.sender
        lst.transfer(msg.sender, amount);
        
        // Update delegation records
        delegations[msg.sender] -= amount;
        totalDelegatedTokens -= amount;
        
        // If delegation is now zero, mark as not a delegator
        if (delegations[msg.sender] == 0) {
            isDelegator[msg.sender] = false;
        }
        
        emit DelegationRemoved(msg.sender, amount);
    }
    
    /**
     * @dev Get the amount delegated by a restaker to an operator
     * @param restaker Address of the restaker
     * @return The amount delegated
     */
    function getDelegatedAmount(address restaker) external view returns (uint256) {
        return delegations[restaker];
    }
    
    /**
     * @dev Get the total amount delegated by a restaker across all operators
     * @param restaker Address of the restaker
     * @return The total amount delegated
     */
    function getTotalDelegatedByRestaker(address restaker) external view returns (uint256) {
        return delegations[restaker];
    }
    
    /**
     * @dev Get the total amount delegated to an operator across all restakers
     * @return The total amount delegated
     */
    function getTotalDelegated() external view returns (uint256) {
        return totalDelegatedTokens;
    }
    
    
    /**
     * @dev Get all restakers who have delegated to an operator
     * @param restakerAddresses Array of restaker addresses to check
     * @return restakers Array of restaker addresses with delegations
     * @return amounts Array of delegated amounts
     */
    function getOperatorDelegations(address[] calldata restakerAddresses) 
        external 
        view 
        returns (address[] memory restakers, uint256[] memory amounts) 
    {
        uint256 count = 0;
        
        // First count how many restakers have delegations
        for (uint256 i = 0; i < restakerAddresses.length; i++) {
            if (delegations[restakerAddresses[i]] > 0) {
                count++;
            }
        }
        
        // Initialize return arrays
        restakers = new address[](count);
        amounts = new uint256[](count);
        
        // Fill return arrays
        uint256 index = 0;
        for (uint256 i = 0; i < restakerAddresses.length; i++) {
            uint256 amount = delegations[restakerAddresses[i]];
            if (amount > 0) {
                restakers[index] = restakerAddresses[i];
                amounts[index] = amount;
                index++;
            }
        }
        
        return (restakers, amounts);
    }

    /**
     * @dev Slash all delegations, converting the tokens to USDC and sending to PUSD
     */
    function slash() external {
        // Store the total delegated amount before resetting
        uint256 amountToSlash = totalDelegatedTokens;
        
        // Clear all delegations
        for (uint256 i = 0; i < delegators.length; i++) {
            address delegator = delegators[i];
            if (delegations[delegator] > 0) {
                delegations[delegator] = 0;
                isDelegator[delegator] = false;
            }
        }
        
        // Reset the delegators array
        delete delegators;
        
        // Reset the total delegated tokens
        totalDelegatedTokens = 0;
        
        // Convert the slashed tokens to USDC and send to PUSD
        lst.convertToUSDCAndSendToPUSD(amountToSlash);
    }

} 