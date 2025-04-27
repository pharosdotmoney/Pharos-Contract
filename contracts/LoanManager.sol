// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {OperatorRegistry} from "./OperatorRegistry.sol";
import {DelegationManager} from "./DelegationManager.sol";
import {PUSD} from "./PUSD.sol";

/**
 * @title LoanManager
 * @dev Contract for managing loans backed by delegated LST tokens
 */
contract LoanManager is Ownable, ReentrancyGuard {
    using Math for uint256;
    
    struct Loan {
        uint256 amount;
        uint256 interestRate; // in basis points (e.g., 500 = 5%)
        uint256 startTime;
        uint256 dueTime;
        bool isRepaid;
        uint256 collateralAmount;
    }
    
    OperatorRegistry public operatorRegistry;
    DelegationManager public delegationManager;
    PUSD public pusdToken;
    
    // Base interest rate in basis points (e.g., 300 = 3%)
    uint256 public baseInterestRate = 300;
    
    // Loan-to-Value ratio in percentage (e.g., 50 = 50%)
    uint256 public ltvRatio = 50;
    
    // Loan duration in seconds (default: 30 days)
    uint256 public loanDuration = 30 days;
    
    // Mapping from operator address to their loan
    mapping(address => Loan) public loans;
    
    // Events
    event LoanCreated(address indexed operator, uint256 amount, uint256 interestRate, uint256 dueTime);
    event LoanRepaid(address indexed operator, uint256 amount, uint256 interest);
    event BaseRateUpdated(uint256 newRate);
    event LTVRatioUpdated(uint256 newRatio);
    
    /**
     * @dev Constructor sets up the LoanManager
     * @param _operatorRegistry Address of the operator registry
     * @param _delegationManager Address of the delegation manager
     * @param _pusdToken Address of the PUSD token
     */
    constructor(
        address _operatorRegistry,
        address _delegationManager,
        address _pusdToken
    ) Ownable(msg.sender) {
        require(_operatorRegistry != address(0), "Invalid operator registry address");
        require(_delegationManager != address(0), "Invalid delegation manager address");
        require(_pusdToken != address(0), "Invalid PUSD token address");
        
        operatorRegistry = OperatorRegistry(_operatorRegistry);
        delegationManager = DelegationManager(_delegationManager);
        pusdToken = PUSD(_pusdToken);
    }
    
    /**
     * @dev Create a loan for an operator based on delegated LST
     * @param amount Amount of PUSD to borrow
     */
    function createLoan(uint256 amount) external nonReentrant {
        require(operatorRegistry.isActiveOperator(msg.sender), "Not an active operator");
        require(amount > 0, "Loan amount must be greater than zero");
        require(loans[msg.sender].amount == 0 || loans[msg.sender].isRepaid, "Existing loan not repaid");
        
        // Get operator's delegated amount
        (,uint256 delegatedAmount,,,) = operatorRegistry.getOperatorDetails(msg.sender);
        
        // Calculate maximum loan amount based on LTV ratio
        uint256 maxLoanAmount = (delegatedAmount * ltvRatio) / 100;
        require(amount <= maxLoanAmount, "Loan amount exceeds maximum allowed");
        
        // Create the loan
        loans[msg.sender] = Loan({
            amount: amount,
            interestRate: baseInterestRate,
            startTime: block.timestamp,
            dueTime: block.timestamp + loanDuration,
            isRepaid: false,
            collateralAmount: delegatedAmount
        });
        
        // Mint PUSD to the operator
        pusdToken.mint(amount);
        
        emit LoanCreated(msg.sender, amount, baseInterestRate, block.timestamp + loanDuration);
    }
    
    /**
     * @dev Repay a loan with interest
     */
    function repayLoan() external nonReentrant {
        Loan storage loan = loans[msg.sender];
        require(loan.amount > 0 && !loan.isRepaid, "No active loan to repay");
        
        // Calculate interest
        uint256 interest = (loan.amount * loan.interestRate * (block.timestamp - loan.startTime)) / (10000 * 365 days);
        uint256 totalRepayment = loan.amount + interest;
        
        // Transfer PUSD from operator to this contract
        bool success = pusdToken.transferFrom(msg.sender, address(this), totalRepayment);
        require(success, "PUSD transfer failed");
        
        // Mark loan as repaid
        loan.isRepaid = true;
        
        emit LoanRepaid(msg.sender, loan.amount, interest);
    }
    
    /**
     * @dev Update the base interest rate
     * @param newRate New base interest rate in basis points
     */
    function updateBaseRate(uint256 newRate) external onlyOwner {
        baseInterestRate = newRate;
        emit BaseRateUpdated(newRate);
    }
    
    /**
     * @dev Update the Loan-to-Value ratio
     * @param newRatio New LTV ratio in percentage
     */
    function updateLTVRatio(uint256 newRatio) external onlyOwner {
        require(newRatio <= 80, "LTV ratio too high");
        ltvRatio = newRatio;
        emit LTVRatioUpdated(newRatio);
    }
    
    /**
     * @dev Get loan details for an operator
     * @param operator Address of the operator
     * @return amount Loan amount
     * @return interestRate Interest rate in basis points
     * @return startTime Loan start time
     * @return dueTime Loan due time
     * @return isRepaid Whether the loan is repaid
     * @return collateralAmount Amount of collateral
     */
    function getLoanDetails(address operator) external view returns (
        uint256 amount,
        uint256 interestRate,
        uint256 startTime,
        uint256 dueTime,
        bool isRepaid,
        uint256 collateralAmount
    ) {
        Loan memory loan = loans[operator];
        return (
            loan.amount,
            loan.interestRate,
            loan.startTime,
            loan.dueTime,
            loan.isRepaid,
            loan.collateralAmount
        );
    }
    
    /**
     * @dev Calculate the current repayment amount for a loan
     * @param operator Address of the operator
     * @return The total repayment amount (principal + interest)
     */
    function calculateRepaymentAmount(address operator) external view returns (uint256) {
        Loan memory loan = loans[operator];
        if (loan.amount == 0 || loan.isRepaid) {
            return 0;
        }
        
        uint256 interest = (loan.amount * loan.interestRate * (block.timestamp - loan.startTime)) / (10000 * 365 days);
        return loan.amount + interest;
    }
} 