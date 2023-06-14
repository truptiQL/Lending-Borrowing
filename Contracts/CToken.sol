import "./LendingAndBorrowing.sol";
import "./InterestRateModel.sol";
import "./CTokenInterface.sol";

contract CToken is CTokenInterface {
    
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _notEntered = true;
    }

    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

    function transferTokens(
        address spender,
        address src,
        address dst,
        uint tokens
    ) internal returns (bool) {
        /* Fail if transfer not allowed */

        // require(
        //     !LendingAndBorrowing.isUnderwater(src, tokens),
        //     "Account is underwater"
        // );

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

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(
        address dst,
        uint256 amount
    ) external nonReentrant returns (bool) {
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
    ) external nonReentrant returns (bool) {
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
    ) external returns (bool) {
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
    ) external view  returns (uint256) {
        return transferAllowances[owner][spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) external view  returns (uint256) {
        return accountTokens[owner];
    }

    function balanceOfUnderlying(address owner) public returns(uint256){
        return (LendingAndBorrowing.currentExchangeRate() * accountTokens[owner]);
    }

    function accrueInterest() public {}

    /// @param mintAmount number of underlying assets
    function mint(uint256 mintAmount, address underlyingToken) public {
        accrueInterest();
        address cToken = address(this);
        address minter = msg.sender;
        require(LendingAndBorrowing.markets[cToken].islisted, "market not listed");
        // for this first we have to check no of underlyings
        // mintAmount == underlying * exchangeRate
        // pehele user underlying transfer karega to this contract then he will get ctoken

        require(
            underlyingToken.transferFrom(minter, address(this), mintAmount),
            "underlying not received"
        );

        mintTokens = mintAmount / LendingAndBorrowing.currentExchangeRate();

        totalSupply += mintTokens;
        accountTokens[minter] += mintTokens;

        emit Mint(minter, mintAmount, mintTokens);
        emit Transfer(address(this), minter, mintTokens);
    }

    function redeemTokens(
        address redeemer,
        uint256 _redeemTokens,
        address underlying
    ) public {
        require(LendingAndBorrowing.markets[address(this)].isListed, "Market not listed");

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        require(LendingAndBorrowing.markets[CToken].accountMembership[redeemer], "Not in a market");

        if (accountTokens[address(this)] < _redeemTokens) {
            revert;
        }

        totalSupply -= _redeemTokens;
        accountTokens[redeemer] += accountTokens[redeemer] - _redeemTokens;

        uint256 redeemAmount = _redeemTokens * LendingAndBorrowing.currentExchangeRate();

        require(
            underlying.transferFrom(address(this), redeemer, redeemAmount),
            "not transfered"
        );

        emit RedeemTokens(redeemer, _redeemTokens);
    }

    function borrow(
        address borrower,
        uint256 borrowAmount,
        address underlying
    ) public {
        // CHECK for underwater??
        require(
            underlying.balanceOf(address(this)) > borrowAmount,
            "This much amount is not available"
        );
        require(
            !LendingAndBorrowing.isUnderwater(address(this), borrowBalance[msg.sender]),
            "Underwater account"
        );
        require(address(this).price() != 0, "Price Error");
        require(LendingAndBorrowing.makets[address(this)].isListed, "market not listed");
        borrowBalance[borrower] += borrowAmount;
        totalBorrows += borrowAmount;

        underlying.transferFrom(address(this), borrower, borrowAmount);
    }

    function repayBorrow(
        address borrower,
        uint256 repayAmount,
        address underlying
    ) public {
        require(
            borrowBalance[borrower] >= repayAmount,
            "Invalid borrow amount"
        );
        underlying.transferFrom(borrower, address(this), repayAmount);

        borrowBalance[borrower] -= repayAmount;
        totalBorrows -= repayAmount;
    }

    function price(address cToken) public virtual {}
}
