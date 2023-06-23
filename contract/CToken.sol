// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "./ComptrollerInterface.sol";
import "./InterestRateModel.sol";
import "./CTokenInterface.sol";
import "./ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract CToken is CTokenInterface, Initializable {
    ComptrollerInterface comptroller;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _comptroller,
        address _interestRateModel,
        address _underlying
    ) public initializer {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _notEntered = true;
        comptroller_ = _comptroller;
        interestRateModel = InterestRateModel(_interestRateModel);
        underlying = _underlying;

        comptroller = ComptrollerInterface(comptroller_);
    }

    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(
        address dst,
        uint256 amount
    ) external override nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, dst, amount) == true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external override nonReentrant returns (bool) {
        return transferTokens(msg.sender, src, dst, amount) == true;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (uint256.max means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return transferAllowances[owner][spender];
    }

    function getAccountSnapshot(
        address account
    ) external view override returns (uint, uint, uint) {
        return (
            accountTokens[account],
            borrowBalance[account],
            currentExchangeRate()
        );
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) public view override returns (uint256) {
        return accountTokens[owner];
    }

    function balanceOfUnderlying(
        address owner
    ) public view override returns (uint256) {
        return (currentExchangeRate() * accountTokens[owner]);
    }

    function accrueInterest() public virtual override {
        /* Remember the initial block number */
        uint currentBlockNumber = block.number;
        uint accrualBlockNumberPrior = accrualBlockNumber;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockNumberPrior == currentBlockNumber) {
            /* Read the previous values out of storage */
            uint cashPrior = getCashPrior();
            uint borrowsPrior = totalBorrows;
            uint reservesPrior = totalReserves;
            uint borrowIndexPrior = borrowIndex;

            /* Calculate the current borrow interest rate */
            uint borrowRateMantissa = interestRateModel.getBorrowRate(
                cashPrior,
                borrowsPrior,
                reservesPrior
            );
            require(
                borrowRateMantissa <= borrowRateMaxMantissa,
                "borrow rate is absurdly high"
            );

            /* Calculate the number of blocks elapsed since the last accrual */
            uint blockDelta = currentBlockNumber - accrualBlockNumberPrior;

            /*
             * Calculate the interest accumulated into borrows and reserves and the new index:
             *  simpleInterestFactor = borrowRate * blockDelta
             *  interestAccumulated = simpleInterestFactor * totalBorrows
             *  totalBorrowsNew = interestAccumulated + totalBorrows
             *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
             *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
             */
            uint simpleInterestFactor = borrowRateMantissa * blockDelta;
            uint interestAccumulated = simpleInterestFactor * borrowsPrior;
            uint totalBorrowsNew = interestAccumulated + borrowsPrior;
            uint totalReservesNew = interestAccumulated * 1 + reservesPrior;
            uint borrowIndexNew = simpleInterestFactor *
                borrowIndexPrior +
                borrowIndexPrior;

            /////////////////////////
            // EFFECTS & INTERACTIONS
            // (No safe failures beyond this point)

            /* We write the previously calculated values into storage */
            accrualBlockNumber = currentBlockNumber;
            borrowIndex = borrowIndexNew;
            totalBorrows = totalBorrowsNew;
            totalReserves = totalReservesNew;

            /* We emit an AccrueInterest event */
            emit AccrueInterest(
                cashPrior,
                interestAccumulated,
                borrowIndexNew,
                totalBorrowsNew
            );
        }
    }

    /// @param mintAmount number of underlying assets
    /// Mint equivalent number of cTokens
    function mintToken(uint256 mintAmount) public override {
        accrueInterest();

        ComptrollerInterface(comptroller).mintAllowed(address(this));

        address cToken = address(this);
        address minter = msg.sender;
        require(
            IERC20(underlying).transferFrom(minter, cToken, mintAmount),
            "underlying not received"
        );

        uint256 mintTokens = mintAmount / currentExchangeRate();

        totalSupply += mintTokens;
        accountTokens[minter] += mintTokens;

        emit Mint(minter, mintAmount, mintTokens);
        emit Transfer(cToken, minter, mintTokens);
    }

    /**
     *
     * @param redeemer will get redeemed Tokens
     * @param _redeemTokens  Number of tokens redeemed
     */
    function redeemTokens(
        address redeemer,
        uint256 _redeemTokens
    ) public override {
        accrueInterest();

        ComptrollerInterface(comptroller).redeemAllowed(
            address(this),
            redeemer,
            _redeemTokens
        );

        if (accountTokens[redeemer] < _redeemTokens) {
            revert();
        }

        totalSupply -= _redeemTokens;
        accountTokens[redeemer] -= accountTokens[redeemer] - _redeemTokens;

        uint256 redeemAmount = _redeemTokens * currentExchangeRate();

        require(
            IERC20(underlying).transfer(redeemer, redeemAmount),
            "not transfered"
        );

        emit Redeem(redeemer, _redeemTokens);
    }

    // It will work for borrow and borrowOnbehalf also
    /**
     *
     * @param borrower Will pay borrow
     * @param borrowAmount Amount repay by the borrower
     */
    function borrow(address borrower, uint256 borrowAmount) public override {
        accrueInterest();
        require(
            getCashPrior() > borrowAmount,
            "This much amount is not available"
        );

       comptroller.borrowAllowed(
            address(this),
            borrower,
            borrowBalance[borrower] + borrowAmount
        );

        borrowBalance[borrower] += borrowAmount;
        totalBorrows += borrowAmount;

        IERC20(underlying).transfer(borrower, borrowAmount);

        emit Borrow(
            borrower,
            borrowAmount,
            borrowBalance[borrower],
            totalBorrows
        );
    }

    /**
     *
     * @param borrower whose borrow will be repaid
     * @param repayAmount Amount repay by function caller
     */
    function repayBorrow(
        address borrower,
        uint256 repayAmount
    ) public override {
        accrueInterest();

        comptroller.repayAllowed(address(this));

        require(
            borrowBalance[borrower] >= repayAmount,
            "Invalid borrow amount"
        );
        IERC20(underlying).transferFrom(msg.sender, address(this), repayAmount);

        borrowBalance[borrower] -= repayAmount;
        totalBorrows -= repayAmount;

        emit RepayBorrow(
            msg.sender,
            borrower,
            repayAmount,
            borrowBalance[borrower],
            totalBorrows
        );
    }

    function currentExchangeRate() public view override returns (uint) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return 1; // let  initialExchangeRate = 1 (Atual = 0.020 or set in initializer)
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint totalCash = getCashPrior();
            uint cashPlusBorrowsMinusReserves = totalCash +
                totalBorrows -
                totalReserves;
            uint exchangeRate = cashPlusBorrowsMinusReserves / _totalSupply;

            return exchangeRate;
        }
    }

    /**
     * get underlying balance of cToken
     */
    function getCashPrior() internal view override returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /**
     * get borrow rate based of ctoken
     */
    function getBorrowRate() internal view override returns (uint256) {
        return
            interestRateModel.getBorrowRate(
                getCashPrior(),
                totalBorrows,
                totalReserves
            );
    }

    /**
     * get supply rate based of ctoken
     */
    function getSupplyRate() internal view override returns (uint256) {
        return
            interestRateModel.getSupplyRate(
                getCashPrior(),
                totalBorrows,
                totalReserves,
                reserveFactorMantissa
            );
    }

    function transferTokens(
        address spender,
        address src,
        address dst,
        uint tokens
    ) internal returns (bool) {
        /* Fail if transfer not allowed */

        /* Do not allow self-transfers */
        if (src == dst) {
            revert();
        }

        /* Get the allowance, infinite for the account owner */
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = type(uint).max;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        /* Do the calculations, checking for {under,over}flow */
        uint allowanceNew = startingAllowance - tokens;
        uint srcTokensNew = accountTokens[src] - tokens;
        uint dstTokensNew = accountTokens[dst] + tokens;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = srcTokensNew;
        accountTokens[dst] = dstTokensNew;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != type(uint).max) {
            transferAllowances[src][spender] = allowanceNew;
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);

        // unused function
        // comptroller.transferVerify(address(this), src, dst, tokens);

        return true;
    }
}
