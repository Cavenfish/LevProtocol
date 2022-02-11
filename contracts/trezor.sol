// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IStablecoin.sol";

// Trezor == Vault
contract Trezor is ERC20 {
    using SafeMath for uint256;
    IERC20 public levToken;

    // Define the Trezor token contract
    constructor(
      string memory _name,
      string memory _symbol,
      IERC20 _levToken,
      address _stablecoinAddress
    ) public ERC20(_name, _symbol) {
        levToken          = _levToken;
        stablecoinAddress = _stablecoinAddress;
        vaultID           = IStablecoin(stablecoinAddress).createVault();
        openFee           = Istablecoin(stablecoinAddress).getClosingFee();
        closeFee          = Istablecoin(stablecoinAddress).getOpeningFee();
    }

    // Enter the vault. Deposit tokens to be leveraged.
    function enter(uint256 _amount) public {

        // Gets the amount of leveraged tokens locked in the contract
        uint256 totalLeverageToken = levToken.balanceOf(address(this));

        // Gets the amount of 2x tokens in existence
        uint256 totalTwoXTokens = totalSupply();

        // Gets the total vault debt
        uint256 totalVaultDebt = IStablecoin(stablecoinAddress).vaultDebt[vaultID]

        // Get total tokens after debt paid
        uint256 totalTokens = totalLeverageToken.sub(totalVaultDebt.mul(1 + closeFee))

        // If no 2x tokens exists, mint it 1:1 to the amount put in
        if (totalTwoXTokens == 0 || totalLeverageToken == 0) {
            _mint(msg.sender, _amount);
        }

        // Calculate and mint the amount of 2x tokens the deposited tokens are worth.
        else {
            uint256 what = _amount.mul(totalTwoXTokens).div(totalTokens);
            _mint(msg.sender, what);
        }

        // Move the tokens into the vault and leverage them
        _leverage(_amount)
    }

    // Leave the vault. Burn 2x tokens to get back original tokens.
    function leave(uint256 _share) public {

        /* Steps missing here
          1) Deleverage token prior to burn/transfer
          SAFTEY CHECK: make sure the burn calculation works with leverage
          SAFTEY CHECK: make sure the burn calculation works with repay fee
        */

        // Gets the amount of to be leveraged tokens locked in the contract
        uint256 totalLeverageToken = levToken.balanceOf(address(this));

        // Gets the amount of 2x tokens in existence
        uint256 totalTwoXTokens = totalSupply();

        // Calculates the amount of GovernanceToken the 2x tokens is worth
        uint256 what = _share.mul(totalLeverageToken).div(totalTwoXTokens);

        //Burn 2x tokens. Transfer original tokens.
        _burn(msg.sender, _share);
        levToken.transfer(msg.sender, what);
    }


    // Supplies tokens to QiDAO to leverage them
    function _supply(uint256 _amount) internal {
        IStablecoin(stablecoinAddress).depositCollateral{value: _amout}(vaultID);
    }

    function _removeSupply(uint256 _amount) internal {
        // Need to convert the amount into tq token amounts
        uint256 tqAmount;
        if (_amount == uint256(-1)) {
            tqAmount = _amount;
        } else {
            tqAmount = _amount.mul(1e18).div(ITranqToken(tqTokenAddress).exchangeRateStored());
        }
        if (tqAmount > IERC20(tqTokenAddress).balanceOf(address(this))) {
            tqAmount = IERC20(tqTokenAddress).balanceOf(address(this));
        }
        ITranqToken(tqTokenAddress).redeem(tqAmount);
    }

    function _borrow(uint256 _amount) internal {
        ITranqToken(tqTokenAddress).borrow(_amount);
    }

    function _repayBorrow(uint256 _amount) internal {
        if (_amount > debtTotal()) {
            _amount = debtTotal();
        }
        if (_amount > 0) {
            ITranqToken(tqTokenAddress).repayBorrow(_amount);
        }
    }

    /**
     * @dev Deposits token, withdraws a percentage, and deposits again
     * We stop at _borrow because we need some tokens to deleverage
     */
    function _leverage(uint256 _amount) internal {
        if (borrowDepth == 0) {
            _supply(_amount);
        } else if (_amount > minLeverage) {
            for (uint256 i = 0; i < borrowDepth; i++) {
                _supply(_amount);
                _amount = _amount.mul(borrowRate).div(BORROW_RATE_DIVISOR);
                _borrow(_amount);
            }
        }
    }

    /**
     * @dev Manually wind back one step in case contract gets stuck
     */
    function deleverageOnce() external onlyGov {
        _deleverageOnce();
    }

    function _deleverageOnce() internal {
        if (tqTokenTotal() <= supplyBalTargeted()) {
            _removeSupply(tqTokenTotal().sub(supplyBalMin()));
        } else {
            _removeSupply(tqTokenTotal().sub(supplyBalTargeted()));
        }

        _repayBorrow(wantLockedInHere());
    }

    /**
     * @dev In Polygon, we can fully deleverage due to absurdly cheap fees
     */
    function _deleverage() internal {
        uint256 wantBal = wantLockedInHere();

        if (borrowDepth > 0) {
            while (wantBal < debtTotal()) {
                _repayBorrow(wantBal);
                _removeSupply(tqTokenTotal().sub(supplyBalMin()));
                wantBal = wantLockedInHere();
            }

            _repayBorrow(wantBal);
        }
        _removeSupply(uint256(-1));
    }
}
