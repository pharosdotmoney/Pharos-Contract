// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PUSD.sol";

/**
 * @title sPUSD Vault
 * @dev An ERC4626 vault that accepts PUSD deposits and mints sPUSD tokens
 */
contract sPUSD is ERC4626, Ownable {
    PUSD public pusdToken;
    address public loanManager;
    uint256 public loanedPUSDCAmount = 0;

    // Events
    event PUSDAddressSet(address indexed pusdAddress);

    /**
     * @dev Constructor sets up the sPUSD vault
     * @param _pusdToken Address of the PUSD token contract
     */
    constructor(
        address _pusdToken
    )
        ERC4626(IERC20(_pusdToken))
        ERC20("Staked PUSD", "sPUSD")
        Ownable(msg.sender)
    {
        require(_pusdToken != address(0), "PUSD address cannot be zero");
        pusdToken = PUSD(_pusdToken);
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        // If asset() is ERC-777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        // SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        pusdToken.transferToSPUSD(caller, assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address _owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != _owner) {
            _spendAllowance(_owner, caller, shares);
        }

        // If asset() is ERC-777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(_owner, shares);
        pusdToken.transfer(receiver, assets);
        // SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, _owner, assets, shares);
    }

    /**
     * @dev Sets the loan manager address
     * @param _loanManager Address of the loan manager contract
     */
    function setLoanManager(address _loanManager) external onlyOwner {
        require(
            _loanManager != address(0),
            "Loan manager address cannot be zero"
        );
        loanManager = _loanManager;
    }

    function transferToOperator(
        uint256 pusdcAmount,
        address operator
    ) external returns (bool) {
        require(
            msg.sender == loanManager,
            "Only loan manager can call this function"
        );
        require(pusdcAmount > 0, "Transfer amount must be greater than zero");
        require(
            pusdToken.balanceOf(address(this)) >= pusdcAmount,
            "Insufficient PUSDC balance"
        );
        pusdToken.transfer(operator, pusdcAmount);
        loanedPUSDCAmount += pusdcAmount;
        return true;
    }

    function transferFromOperator(
        uint256 pusdcAmount,
        address operator
    ) external returns (bool) {
        require(
            msg.sender == loanManager,
            "Only loan manager can call this function"
        );
        require(pusdcAmount > 0, "Transfer amount must be greater than zero");
        require(
            pusdToken.balanceOf(operator) >= pusdcAmount,
            "Insufficient PUSDC balance"
        );
        pusdToken.transferFromOperator(pusdcAmount, operator, address(this));
        loanedPUSDCAmount -= pusdcAmount;
        return true;
    }

    /**
     * @dev Returns the number of decimals used by the token
     * @return The number of decimals (18 for standard ERC20)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
