// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IOperator.sol";
import "./OperatorRegistry.sol";
import "./LoanManager.sol";
import "./PUSD.sol";

/**
 * @title Operator Implementation
 * @dev Implementation of the Operator interface
 */
contract Operator is IOperator {
    OperatorRegistry public operatorRegistry;
    LoanManager public loanManager;
    PUSD public pusdToken;
    
    address public owner;
    
    /**
     * @dev Constructor sets up the Operator
     * @param _operatorRegistry Address of the operator registry
     * @param _loanManager Address of the loan manager
     * @param _pusdToken Address of the PUSD token
     */
    constructor(
        address _operatorRegistry,
        address _loanManager,
        address _pusdToken
    ) {
        require(_operatorRegistry != address(0), "Invalid operator registry address");
        require(_loanManager != address(0), "Invalid loan manager address");
        require(_pusdToken != address(0), "Invalid PUSD token address");
        
        operatorRegistry = OperatorRegistry(_operatorRegistry);
        loanManager = LoanManager(_loanManager);
        pusdToken = PUSD(_pusdToken);
        owner = msg.sender;
    }
    
    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    /**
     * @dev Register as an operator in the system
     * @param name Name of the operator
     * @param metadataURI URI pointing to operator metadata
     */
    function register(string memory name, string memory metadataURI) external override onlyOwner {
        operatorRegistry.registerOperator(address(this), name, metadataURI);
    }
    
    /**
     * @dev Get the total amount delegated to this operator
     * @return The total delegated amount
     */
    function getTotalDelegated() external view override returns (uint256) {
        (,uint256 totalDelegated,,,) = operatorRegistry.getOperatorDetails(address(this));
        return totalDelegated;
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
        uint256 repaymentAmount = loanManager.calculateRepaymentAmount(address(this));
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
        (amount,,,dueTime,isRepaid,) = loanManager.getLoanDetails(address(this));
        return (amount, dueTime, isRepaid);
    }
    
    /**
     * @dev Calculate the current repayment amount
     * @return The total repayment amount (principal + interest)
     */
    function getRepaymentAmount() external view override returns (uint256) {
        return loanManager.calculateRepaymentAmount(address(this));
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
} 