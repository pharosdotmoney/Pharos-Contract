// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Eigen.sol";
import "./sPUSD.sol";
import "./IOperator.sol";
import "./PUSD.sol";

/**
 * @title LoanManager
 * @dev Contract for managing loans backed by delegated LST tokens
 */
contract LoanManager is Ownable {
    using Math for uint256;

    struct Loan {
        uint256 amount;
        uint256 interestRate; // in basis points (e.g., 500 = 5%)
        uint256 startTime;
        uint256 dueTime;
        bool isRepaid;
        uint256 collateralAmount;
        uint256 loanedUSDCAmount;
        bool isSlashed;
    }

    Eigen public eigen;
    sPUSD public spusdToken;
    IOperator public operator;
    PUSD public pusdToken;

    // Base interest rate in basis points (e.g., 300 = 3%)
    uint256 public baseInterestRate = 1000;

    // Loan-to-Value ratio in percentage (e.g., 50 = 50%)
    uint256 public ltvRatio = 50;

    // Loan duration in seconds (default: 1 days)
    uint256 public loanDuration = 1 days;

    // only one operator is there
    // no need for mapping
    Loan public loan;

    // Events
    event LoanCreated(
        address indexed operator,
        uint256 amount,
        uint256 interestRate,
        uint256 dueTime
    );
    event LoanRepaid(
        address indexed operator,
        uint256 amount,
        uint256 interest
    );
    event BaseRateUpdated(uint256 newRate);
    event LTVRatioUpdated(uint256 newRatio);
    event LoanSlashed(address indexed operator, uint256 amount);

    /**
     * @dev Constructor sets up the LoanManager
     * @param _eigen Address of the eigen
     * @param _spusdToken Address of the sPUSD token
     * @param _operator Address of the operator
     */
    constructor(
        address _eigen,
        address _spusdToken,
        address _operator
    ) Ownable(msg.sender) {
        require(_eigen != address(0), "Invalid eigen address");
        require(_spusdToken != address(0), "Invalid sPUSD token address");
        require(_operator != address(0), "Invalid operator address");

        eigen = Eigen(_eigen);
        spusdToken = sPUSD(_spusdToken);
        operator = IOperator(_operator);
    }

    function setPUSDToken(address _pusdToken) external onlyOwner {
        require(_pusdToken != address(0), "Invalid PUSD token address");
        pusdToken = PUSD(_pusdToken);
    }

    /**
     * @dev Create a loan for an operator based on delegated LST
     * @param amount Amount of PUSD to borrow
     */
    function createLoan(uint256 amount) external {
        require(amount > 0, "Loan amount must be greater than zero");
        require(loan.amount == 0 || loan.isRepaid, "Existing loan not repaid");

        // Get operator's delegated amount
        uint256 delegatedAmount = eigen.getTotalDelegated();

        // Calculate maximum loan amount based on LTV ratio
        uint256 maxLoanAmount = (delegatedAmount * ltvRatio) / 100;
        require(amount <= maxLoanAmount, "Loan amount exceeds maximum allowed");

        // Create the loan
        loan = Loan({
            amount: amount,
            interestRate: baseInterestRate,
            startTime: block.timestamp,
            dueTime: block.timestamp + loanDuration,
            isRepaid: false,
            collateralAmount: delegatedAmount,
            loanedUSDCAmount: 0,
            isSlashed: false
        });

        // transfer pusdc to the operator from pusd contract
        bool success = spusdToken.transferToOperator(amount, address(operator));
        require(success, "PUSD transfer failed");

        emit LoanCreated(
            msg.sender,
            amount,
            baseInterestRate,
            block.timestamp + loanDuration
        );
    }

    /**
     * @dev Repay a loan with interest
     */
    function repayLoan() external {
        require(loan.amount > 0 && !loan.isRepaid, "No active loan to repay");

        // Calculate fixed 10% interest
        uint256 interest = loan.amount;
        uint256 totalRepayment = loan.amount;

        // Check if operator has enough PUSD tokens
        require(
            pusdToken.balanceOf(address(operator)) >= totalRepayment,
            "Operator does not have enough PUSD tokens"
        );

        // Transfer PUSD from operator to this contract
        bool transferSuccess = spusdToken.transferFromOperator(
            totalRepayment,
            address(operator)
        );
        require(transferSuccess, "PUSD transfer failed");
        // Mark loan as repaid
        loan.isRepaid = true;
        loan.isSlashed = false;

        emit LoanRepaid(msg.sender, loan.amount, interest);
    }

    function slashLoan() external returns (bool) {
        require(loan.amount > 0 && !loan.isRepaid, "No active loan to slash");
        // require(block.timestamp > loan.dueTime, "Loan is not due yet");
        require(!loan.isSlashed, "Loan already slashed");

        // Store the loan amount before slashing
        uint256 loanAmount = loan.amount;

        // Call eigen to slash the delegations
        eigen.slash();

        // Update loan state
        loan.isRepaid = true;
        loan.isSlashed = true;
        loan.amount = 0; // Clear the loan amount

        emit LoanSlashed(msg.sender, loanAmount);
        return true;
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
     * @return amount Loan amount
     * @return interestRate Interest rate in basis points
     * @return startTime Loan start time
     * @return dueTime Loan due time
     * @return isRepaid Whether the loan is repaid
     * @return collateralAmount Amount of collateral
     */
    function getLoanDetails()
        external
        view
        returns (
            uint256 amount,
            uint256 interestRate,
            uint256 startTime,
            uint256 dueTime,
            bool isRepaid,
            uint256 collateralAmount,
            uint256 loanedUSDCAmount,
            bool isSlashed
        )
    {
        return (
            loan.amount,
            loan.interestRate,
            loan.startTime,
            loan.dueTime,
            loan.isRepaid,
            loan.collateralAmount,
            loan.loanedUSDCAmount,
            loan.isSlashed
        );
    }

    /**
     * @dev Calculate the current repayment amount for a loan
     * @return The total repayment amount (principal + interest)
     */
    function calculateRepaymentAmount() external view returns (uint256) {
        if (loan.amount == 0 || loan.isRepaid) {
            return 0;
        }

        // use safe math for division
        // uint256 interest = loan.amount;
        return loan.amount;
    }
}
