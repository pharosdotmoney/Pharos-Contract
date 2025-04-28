// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IOperator.sol";
import "./LoanManager.sol";
import "./PUSD.sol";
import "./Eigen.sol";

/**
 * @title Operator Implementation
 * @dev Implementation of the Operator interface
 */
contract Operator is IOperator {
    Eigen public eigen;
    LoanManager public loanManager;
    PUSD public pusdToken;
    
    address public owner;
    
    /**
     * @dev Constructor sets up the Operator
     */
    constructor(
    ) {
        owner = msg.sender;
    }
    
    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    function setPUSD(address _pusdToken) external onlyOwner {
        require(_pusdToken != address(0), "Invalid PUSD token address");
        pusdToken = PUSD(_pusdToken);
    }

    function setLoanManager(address _loanManager) external onlyOwner {
        require(_loanManager != address(0), "Invalid loan manager address");
        loanManager = LoanManager(_loanManager);
    } 

    function setEigen(address _eigen) external onlyOwner {
        require(_eigen != address(0), "Invalid eigen address");
        eigen = Eigen(_eigen);
    }

    /**
     * @dev Create a loan based on delegated tokens
     * @param amount Amount to borrow
     */
    function borrowAgainstDelegation(uint256 amount) external override onlyOwner {
        loanManager.createLoan(amount);
    }
    
    /**
     * @dev Repay an existing loan
     */
    function repayLoan() external override onlyOwner {
        // Approve PUSD transfer to loan manager
        uint256 repaymentAmount = loanManager.calculateRepaymentAmount();
        pusdToken.approve(address(loanManager), repaymentAmount);
        
        // Repay the loan
        loanManager.repayLoan();
    }
    
    /**
     * @dev Get the current loan status
     * @return amount Loan amount
     * @return dueTime Loan due time
     * @return isRepaid Whether the loan is repaid
     */
    function getLoanStatus() external view override returns (
        uint256 amount,
        uint256 dueTime,
        bool isRepaid
    ) {
        (amount,,,dueTime,isRepaid,,) = loanManager.getLoanDetails();
        return (amount, dueTime, isRepaid);
    }
    
    /**
     * @dev Calculate the current repayment amount
     * @return The total repayment amount (principal + interest)
     */
    function getRepaymentAmount() external view override returns (uint256) {
        return loanManager.calculateRepaymentAmount();
    }
    
    /**
     * @dev Transfer PUSD tokens from this contract
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transferPUSD(address to, uint256 amount) external onlyOwner {
        pusdToken.transfer(to, amount);
    }
    
    /**
     * @dev Recover any ERC20 tokens accidentally sent to this contract
     * @param token Address of the token
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function getTotalDelegated() external view returns (uint256) {
        return eigen.getTotalDelegated();
    }
} 