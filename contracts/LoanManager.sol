// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LoanManager
 * @dev Contract for managing loans in the CUSD ecosystem
 */
contract LoanManager is Ownable, ReentrancyGuard {
    using Math for uint256;
    
    // Loan struct to store loan information
    struct Loan {
        uint256 amount;        // Amount borrowed
        uint256 interestRate;  // Annual interest rate (in basis points, e.g., 500 = 5%)
        uint256 startTime;     // When the loan was taken
        uint256 duration;      // Loan duration in seconds
        uint256 collateral;    // Amount of collateral provided
        bool active;           // Whether the loan is active
        uint256 repaid;        // Amount already repaid
    }
    
    // Mapping from borrower address to their loans
    mapping(address => Loan[]) public loans;
    
    // The CUSD token
    IERC20 public cusdToken;
    
    // The collateral token (e.g., ETH or another token)
    IERC20 public collateralToken;
    
    // Minimum collateralization ratio (in percentage, e.g., 150 = 150%)
    uint256 public minCollateralRatio = 150;
    
    // Events
    event LoanCreated(address indexed borrower, uint256 loanId, uint256 amount, uint256 collateral);
    event LoanRepaid(address indexed borrower, uint256 loanId, uint256 amount);
    event LoanFullyRepaid(address indexed borrower, uint256 loanId);
    event CollateralReturned(address indexed borrower, uint256 loanId, uint256 amount);
    event LoanLiquidated(address indexed borrower, uint256 loanId, uint256 collateralLiquidated);
    
    /**
     * @dev Constructor sets up the loan manager with token addresses
     * @param _cusdToken Address of the CUSD token
     * @param _collateralToken Address of the collateral token
     * @param initialOwner Address of the contract owner
     */
    constructor(address _cusdToken, address _collateralToken, address initialOwner) 
        Ownable(initialOwner) 
    {
        require(_cusdToken != address(0), "CUSD token address cannot be zero");
        require(_collateralToken != address(0), "Collateral token address cannot be zero");
        
        cusdToken = IERC20(_cusdToken);
        collateralToken = IERC20(_collateralToken);
    }
    
    /**
     * @dev Creates a new loan for the caller
     * @param amount Amount of CUSD to borrow
     * @param collateralAmount Amount of collateral to provide
     * @param duration Loan duration in seconds
     * @param interestRate Annual interest rate in basis points
     */
    function createLoan(
        uint256 amount, 
        uint256 collateralAmount, 
        uint256 duration, 
        uint256 interestRate
    ) external nonReentrant {
        require(amount > 0, "Loan amount must be greater than zero");
        require(collateralAmount > 0, "Collateral amount must be greater than zero");
        require(duration > 0, "Loan duration must be greater than zero");
        
        // Check if collateral is sufficient
        uint256 collateralValue = getCollateralValue(collateralAmount);
        require(
            collateralValue * 100 >= amount * minCollateralRatio,
            "Insufficient collateral for loan amount"
        );
        
        // Transfer collateral from borrower to this contract
        bool collateralTransferred = collateralToken.transferFrom(
            msg.sender, 
            address(this), 
            collateralAmount
        );
        require(collateralTransferred, "Collateral transfer failed");
        
        // Create the loan
        Loan memory newLoan = Loan({
            amount: amount,
            interestRate: interestRate,
            startTime: block.timestamp,
            duration: duration,
            collateral: collateralAmount,
            active: true,
            repaid: 0
        });
        
        // Add loan to borrower's loans
        loans[msg.sender].push(newLoan);
        uint256 loanId = loans[msg.sender].length - 1;
        
        // Transfer CUSD to borrower
        bool cusdTransferred = cusdToken.transfer(msg.sender, amount);
        require(cusdTransferred, "CUSD transfer failed");
        
        emit LoanCreated(msg.sender, loanId, amount, collateralAmount);
    }
    
    /**
     * @dev Repays part or all of a loan
     * @param loanId ID of the loan to repay
     * @param amount Amount to repay
     */
    function repayLoan(uint256 loanId, uint256 amount) external nonReentrant {
        require(loanId < loans[msg.sender].length, "Loan does not exist");
        Loan storage loan = loans[msg.sender][loanId];
        
        require(loan.active, "Loan is not active");
        require(amount > 0, "Repayment amount must be greater than zero");
        
        // Calculate total amount due (principal + interest)
        uint256 totalDue = calculateTotalDue(loan);
        uint256 remainingDue = totalDue - loan.repaid;
        
        // Ensure repayment doesn't exceed what's due
        uint256 actualRepayment = amount > remainingDue ? remainingDue : amount;
        
        // Transfer CUSD from borrower to this contract
        bool transferred = cusdToken.transferFrom(msg.sender, address(this), actualRepayment);
        require(transferred, "CUSD transfer failed");
        
        // Update loan repaid amount
        loan.repaid += actualRepayment;
        
        emit LoanRepaid(msg.sender, loanId, actualRepayment);
        
        // If loan is fully repaid, return collateral and mark as inactive
        if (loan.repaid >= totalDue) {
            loan.active = false;
            
            // Return collateral to borrower
            bool collateralReturned = collateralToken.transfer(msg.sender, loan.collateral);
            require(collateralReturned, "Collateral return failed");
            
            emit LoanFullyRepaid(msg.sender, loanId);
            emit CollateralReturned(msg.sender, loanId, loan.collateral);
        }
    }
    
    /**
     * @dev Calculates the total amount due for a loan (principal + interest)
     * @param loan The loan to calculate for
     * @return Total amount due
     */
    function calculateTotalDue(Loan memory loan) public view returns (uint256) {
        uint256 elapsedTime = block.timestamp - loan.startTime;
        uint256 effectiveDuration = elapsedTime < loan.duration ? elapsedTime : loan.duration;
        
        // Calculate interest: principal * rate * time / (100% * 1 year in seconds)
        uint256 interest = loan.amount * loan.interestRate * effectiveDuration / (10000 * 365 days);
        
        return loan.amount + interest;
    }
    
    /**
     * @dev Gets the value of collateral in terms of loan currency
     * @param collateralAmount Amount of collateral
     * @return Value of collateral
     */
    function getCollateralValue(uint256 collateralAmount) public view returns (uint256) {
        // In a real implementation, this would use an oracle to get the price
        // For simplicity, we're assuming 1:1 value here
        return collateralAmount;
    }
    
    /**
     * @dev Gets all loans for a borrower
     * @param borrower Address of the borrower
     * @return Array of loans
     */
    function getLoansByBorrower(address borrower) external view returns (Loan[] memory) {
        return loans[borrower];
    }
    
    /**
     * @dev Gets a specific loan for a borrower
     * @param borrower Address of the borrower
     * @param loanId ID of the loan
     * @return The loan
     */
    function getLoan(address borrower, uint256 loanId) external view returns (Loan memory) {
        require(loanId < loans[borrower].length, "Loan does not exist");
        return loans[borrower][loanId];
    }
    
    /**
     * @dev Sets the minimum collateralization ratio
     * @param ratio New minimum collateralization ratio
     */
    function setMinCollateralRatio(uint256 ratio) external onlyOwner {
        require(ratio >= 100, "Ratio must be at least 100%");
        minCollateralRatio = ratio;
    }
    
    /**
     * @dev Liquidates a loan if it falls below the minimum collateralization ratio
     * @param borrower Address of the borrower
     * @param loanId ID of the loan
     */
    function liquidateLoan(address borrower, uint256 loanId) external nonReentrant onlyOwner {
        require(loanId < loans[borrower].length, "Loan does not exist");
        Loan storage loan = loans[borrower][loanId];
        
        require(loan.active, "Loan is not active");
        
        uint256 totalDue = calculateTotalDue(loan);
        uint256 remainingDue = totalDue - loan.repaid;
        uint256 collateralValue = getCollateralValue(loan.collateral);
        
        // Check if loan is undercollateralized
        require(
            collateralValue * 100 < remainingDue * minCollateralRatio,
            "Loan is not eligible for liquidation"
        );
        
        // Mark loan as inactive
        loan.active = false;
        
        // Transfer collateral to contract owner (or could be sent to a liquidation pool)
        bool collateralTransferred = collateralToken.transfer(owner(), loan.collateral);
        require(collateralTransferred, "Collateral transfer failed");
        
        emit LoanLiquidated(borrower, loanId, loan.collateral);
    }
} 