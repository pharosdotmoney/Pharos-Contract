// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Operator Registry
 * @dev Contract for registering and managing operators in the restaking system
 */
contract OperatorRegistry is Ownable {
    struct Operator {
        string name;
        address operatorAddress;
        uint256 totalDelegated;
        bool isActive;
        uint256 registrationTime;
        string metadataURI;
    }
    
    // Mapping from operator address to Operator struct
    mapping(address => Operator) public operators;
    
    // Array to keep track of all operator addresses
    address[] public operatorAddresses;
    
    // Events
    event OperatorRegistered(address indexed operatorAddress, string name);
    event OperatorUpdated(address indexed operatorAddress, string name, bool isActive);
    event OperatorDelegationUpdated(address indexed operatorAddress, uint256 totalDelegated);
    
    /**
     * @dev Constructor sets up the OperatorRegistry
     * @param initialOwner Address of the contract owner
     */
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @dev Register a new operator
     * @param operatorAddress Address of the operator
     * @param name Name of the operator
     * @param metadataURI URI pointing to operator metadata
     */
    function registerOperator(address operatorAddress, string memory name, string memory metadataURI) external {
        require(operatorAddress != address(0), "Invalid operator address");
        require(operators[operatorAddress].operatorAddress == address(0), "Operator already registered");
        
        operators[operatorAddress] = Operator({
            name: name,
            operatorAddress: operatorAddress,
            totalDelegated: 0,
            isActive: true,
            registrationTime: block.timestamp,
            metadataURI: metadataURI
        });
        
        operatorAddresses.push(operatorAddress);
        
        emit OperatorRegistered(operatorAddress, name);
    }
    
    /**
     * @dev Update operator details
     * @param operatorAddress Address of the operator
     * @param name New name for the operator
     * @param isActive New active status for the operator
     * @param metadataURI New URI pointing to operator metadata
     */
    function updateOperator(
        address operatorAddress, 
        string memory name, 
        bool isActive, 
        string memory metadataURI
    ) external onlyOwner {
        require(operators[operatorAddress].operatorAddress != address(0), "Operator not registered");
        
        operators[operatorAddress].name = name;
        operators[operatorAddress].isActive = isActive;
        operators[operatorAddress].metadataURI = metadataURI;
        
        emit OperatorUpdated(operatorAddress, name, isActive);
    }
    
    /**
     * @dev Update the total delegated amount for an operator
     * @param operatorAddress Address of the operator
     * @param totalDelegated New total delegated amount
     */
    function updateDelegation(address operatorAddress, uint256 totalDelegated) external {
        require(msg.sender == owner() || msg.sender == address(this), "Not authorized");
        require(operators[operatorAddress].operatorAddress != address(0), "Operator not registered");
        
        operators[operatorAddress].totalDelegated = totalDelegated;
        
        emit OperatorDelegationUpdated(operatorAddress, totalDelegated);
    }
    
    /**
     * @dev Check if an address is a registered operator
     * @param operatorAddress Address to check
     * @return True if the address is a registered and active operator
     */
    function isActiveOperator(address operatorAddress) external view returns (bool) {
        return operators[operatorAddress].isActive;
    }
    
    /**
     * @dev Get the total number of registered operators
     * @return The number of registered operators
     */
    function getOperatorCount() external view returns (uint256) {
        return operatorAddresses.length;
    }
    
    /**
     * @dev Get operator details
     * @param operatorAddress Address of the operator
     * @return name Name of the operator
     * @return totalDelegated Total amount delegated to the operator
     * @return isActive Whether the operator is active
     * @return registrationTime When the operator was registered
     * @return metadataURI URI pointing to operator metadata
     */
    function getOperatorDetails(address operatorAddress) external view returns (
        string memory name,
        uint256 totalDelegated,
        bool isActive,
        uint256 registrationTime,
        string memory metadataURI
    ) {
        Operator memory op = operators[operatorAddress];
        return (
            op.name,
            op.totalDelegated,
            op.isActive,
            op.registrationTime,
            op.metadataURI
        );
    }
} 