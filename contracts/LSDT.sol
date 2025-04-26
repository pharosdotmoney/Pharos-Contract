// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RestakingLST.sol";
import "./OperatorRegistry.sol";

/**
 * @title LST Delegation Tracker
 * @dev Contract for tracking LST token delegations from restakers to operators
 */
contract LSDT is Ownable, ReentrancyGuard {
    // Reference to the LST token contract
    RestakingLST public lstToken;
    
    // Reference to the operator registry
    OperatorRegistry public operatorRegistry;
    
    // Mapping: restaker address => operator address => delegated amount
    mapping(address => mapping(address => uint256)) public delegations;
    
    // Mapping: restaker address => total delegated amount
    mapping(address => uint256) public totalDelegatedByRestaker;
    
    // Mapping: operator address => total delegated amount
    mapping(address => uint256) public totalDelegatedToOperator;
    
    // Total delegated LST tokens across all restakers and operators
    uint256 public totalDelegatedTokens;
    
    // Events
    event DelegationAdded(address indexed restaker, address indexed operator, uint256 amount);
    event DelegationRemoved(address indexed restaker, address indexed operator, uint256 amount);
    event DelegationTransferred(address indexed restaker, address indexed fromOperator, address indexed toOperator, uint256 amount);
    
    /**
     * @dev Constructor sets up the LSDT contract
     * @param _lstToken Address of the LST token contract
     * @param _operatorRegistry Address of the operator registry
     */
    constructor(address _lstToken, address _operatorRegistry) Ownable(msg.sender) {
        require(_lstToken != address(0), "LST token address cannot be zero");
        require(_operatorRegistry != address(0), "Operator registry address cannot be zero");
        
        lstToken = RestakingLST(_lstToken);
        operatorRegistry = OperatorRegistry(_operatorRegistry);
    }
    
    /**
     * @dev Add a delegation record (called by DelegationManager)
     * @param restaker Address of the restaker
     * @param operator Address of the operator
     * @param amount Amount of LST tokens delegated
     */
    function addDelegation(address restaker, address operator, uint256 amount) external nonReentrant {
        require(msg.sender == owner() || msg.sender == address(this), "Not authorized");
        require(restaker != address(0), "Restaker address cannot be zero");
        require(operator != address(0), "Operator address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(operatorRegistry.isActiveOperator(operator), "Operator not active");
        
        // Update delegation records
        delegations[restaker][operator] += amount;
        totalDelegatedByRestaker[restaker] += amount;
        totalDelegatedToOperator[operator] += amount;
        totalDelegatedTokens += amount;
        
        emit DelegationAdded(restaker, operator, amount);
    }
    
    /**
     * @dev Remove a delegation record (called by DelegationManager)
     * @param restaker Address of the restaker
     * @param operator Address of the operator
     * @param amount Amount of LST tokens to undelegate
     */
    function removeDelegation(address restaker, address operator, uint256 amount) external nonReentrant {
        require(msg.sender == owner() || msg.sender == address(this), "Not authorized");
        require(restaker != address(0), "Restaker address cannot be zero");
        require(operator != address(0), "Operator address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");
        require(delegations[restaker][operator] >= amount, "Insufficient delegated amount");
        
        // Update delegation records
        delegations[restaker][operator] -= amount;
        totalDelegatedByRestaker[restaker] -= amount;
        totalDelegatedToOperator[operator] -= amount;
        totalDelegatedTokens -= amount;
        
        emit DelegationRemoved(restaker, operator, amount);
    }
    
    /**
     * @dev Transfer delegation from one operator to another
     * @param fromOperator Address of the current operator
     * @param toOperator Address of the new operator
     * @param amount Amount of LST tokens to transfer
     */
    function transferDelegation(address fromOperator, address toOperator, uint256 amount) external nonReentrant {
        require(fromOperator != address(0), "From operator address cannot be zero");
        require(toOperator != address(0), "To operator address cannot be zero");
        require(fromOperator != toOperator, "Cannot transfer to the same operator");
        require(amount > 0, "Amount must be greater than zero");
        require(delegations[msg.sender][fromOperator] >= amount, "Insufficient delegated amount");
        require(operatorRegistry.isActiveOperator(toOperator), "To operator not active");
        
        // Update delegation records
        delegations[msg.sender][fromOperator] -= amount;
        delegations[msg.sender][toOperator] += amount;
        totalDelegatedToOperator[fromOperator] -= amount;
        totalDelegatedToOperator[toOperator] += amount;
        
        emit DelegationTransferred(msg.sender, fromOperator, toOperator, amount);
    }
    
    /**
     * @dev Get the amount delegated by a restaker to an operator
     * @param restaker Address of the restaker
     * @param operator Address of the operator
     * @return The amount delegated
     */
    function getDelegatedAmount(address restaker, address operator) external view returns (uint256) {
        return delegations[restaker][operator];
    }
    
    /**
     * @dev Get the total amount delegated by a restaker across all operators
     * @param restaker Address of the restaker
     * @return The total amount delegated
     */
    function getTotalDelegatedByRestaker(address restaker) external view returns (uint256) {
        return totalDelegatedByRestaker[restaker];
    }
    
    /**
     * @dev Get the total amount delegated to an operator across all restakers
     * @param operator Address of the operator
     * @return The total amount delegated
     */
    function getTotalDelegatedToOperator(address operator) external view returns (uint256) {
        return totalDelegatedToOperator[operator];
    }
    
    /**
     * @dev Get all operators a restaker has delegated to
     * @param restaker Address of the restaker
     * @param operatorAddresses Array of operator addresses to check
     * @return operators Array of operator addresses with delegations
     * @return amounts Array of delegated amounts
     */
    function getRestakerDelegations(address restaker, address[] calldata operatorAddresses) 
        external 
        view 
        returns (address[] memory operators, uint256[] memory amounts) 
    {
        uint256 count = 0;
        
        // First count how many operators have delegations
        for (uint256 i = 0; i < operatorAddresses.length; i++) {
            if (delegations[restaker][operatorAddresses[i]] > 0) {
                count++;
            }
        }
        
        // Initialize return arrays
        operators = new address[](count);
        amounts = new uint256[](count);
        
        // Fill return arrays
        uint256 index = 0;
        for (uint256 i = 0; i < operatorAddresses.length; i++) {
            uint256 amount = delegations[restaker][operatorAddresses[i]];
            if (amount > 0) {
                operators[index] = operatorAddresses[i];
                amounts[index] = amount;
                index++;
            }
        }
        
        return (operators, amounts);
    }
    
    /**
     * @dev Get all restakers who have delegated to an operator
     * @param operator Address of the operator
     * @param restakerAddresses Array of restaker addresses to check
     * @return restakers Array of restaker addresses with delegations
     * @return amounts Array of delegated amounts
     */
    function getOperatorDelegations(address operator, address[] calldata restakerAddresses) 
        external 
        view 
        returns (address[] memory restakers, uint256[] memory amounts) 
    {
        uint256 count = 0;
        
        // First count how many restakers have delegations
        for (uint256 i = 0; i < restakerAddresses.length; i++) {
            if (delegations[restakerAddresses[i]][operator] > 0) {
                count++;
            }
        }
        
        // Initialize return arrays
        restakers = new address[](count);
        amounts = new uint256[](count);
        
        // Fill return arrays
        uint256 index = 0;
        for (uint256 i = 0; i < restakerAddresses.length; i++) {
            uint256 amount = delegations[restakerAddresses[i]][operator];
            if (amount > 0) {
                restakers[index] = restakerAddresses[i];
                amounts[index] = amount;
                index++;
            }
        }
        
        return (restakers, amounts);
    }
} 