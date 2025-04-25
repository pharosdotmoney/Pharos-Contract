// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Operator Interface
 * @dev Interface for operators in the restaking system
 */
interface IOperator {
    /**
     * @dev Register as an operator in the system
     * @param name Name of the operator
     * @param metadataURI URI pointing to operator metadata
     */
    function register(string memory name, string memory metadataURI) external;
    
    /**
     * @dev Get the total amount delegated to this operator
     * @return The total delegated amount
     */
    function getTotalDelegated() external view returns (uint256);
    
    /**
     * @dev Create a loan based on delegated tokens
     * @param amount Amount to borrow
     */
    function borrowAgainstDelegation(uint256 amount) external;
    
    /**
     * @dev Repay an existing loan
     */
    function repayLoan() external;
    
    /**
     * @dev Get the current loan status
     * @return amount Loan amount
     * @return dueTime Loan due time
     * @return isRepaid Whether the loan is repaid
     */
    function getLoanStatus() external view returns (
        uint256 amount,
        uint256 dueTime,
        bool isRepaid
    );
    
    /**
     * @dev Calculate the current repayment amount
     * @return The total repayment amount (principal + interest)
     */
    function getRepaymentAmount() external view returns (uint256);
} 