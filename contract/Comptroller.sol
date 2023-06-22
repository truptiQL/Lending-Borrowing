// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./ComptrollerInterface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Comptroller is ComptrollerInterface, Initializable {
    uint256 collateralFactor;
    uint256[49] private __gap;

    function initialize() public initializer {
        admin = msg.sender;
        collateralFactor = 8 * 1e17; //0.8
    }

    /**
     *
     * @param cToken will be enter in market
     */

    function enterMarket(CToken cToken) public override {
        addToTheMarket(cToken, msg.sender);
    }

    /**
     * @notice Add the market to the markets mapping and set it as listed
     * @dev Admin function to set isListed and add support for the market
     * @param cToken The address of the market (token) to list
     */

    function supportMarket(CToken cToken) external override {
        require(msg.sender == admin, "only admin can call this function");
        require(!markets[address(cToken)].isListed, "Market already listed");

        cToken.isCToken(); // Exrtra sanity check to ensure that it is really a cToken
        markets[address(cToken)].isListed = true;

        emit MarketAdded(address(cToken));
    }

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external override {
        require(markets[cToken].isListed, "Market not listed");

        //Market of cToken should be there to enable borrow
        if (!markets[cToken].accountMembership[borrower]) {
            addToTheMarket(CToken(cToken), borrower);
        }

        //If shortfall is not 0 then user is not allowed to borrow

        (, uint shortfall) = getAccountLiquidity(
            borrower,
            cToken,
            0,
            borrowAmount
        );
        require(shortfall == 0, "Insufficient liquidity");
    }

    function mintAllowed(address cToken) external view override {
        //cToken market must be present to mint
        require(markets[cToken].isListed, "market not listed");
    }

    function repayAllowed(address cToken) external view override {
        //cToken market must be present to repay
        require(markets[cToken].isListed, "market not listed");
    }

    function exitMarket(address cTokenAddress) public override {
        CToken cToken = CToken(cTokenAddress);
        (uint256 tokensHeld, uint256 amountOwed, ) = cToken.getAccountSnapshot(
            msg.sender
        );

        require(
            amountOwed == 0,
            "Sender has a borrow balance, can't exit market"
        );
        redeemAllowed(cTokenAddress, msg.sender, tokensHeld);

        Market storage marketToExit = markets[address(cToken)];

        /* Return true if the sender is not already ‘in’ the market */
        if (marketToExit.accountMembership[msg.sender]) {
            /* Set cToken account membership to false */
            delete marketToExit.accountMembership[msg.sender];
            CToken[] memory userAssetList = accountAssets[msg.sender];
            uint256 len = userAssetList.length;
            uint256 index;
            for (uint256 i = 0; i < len; i++) {
                if (userAssetList[i] == cToken) {
                    index = i;
                    break;
                }
            }

            // copy last item in list to location of item to be removed, reduce length by 1
            CToken[] storage storedList = accountAssets[msg.sender];
            storedList[index] = storedList[storedList.length - 1];
            storedList.pop();

            emit MatketExit(address(cToken));
        }
    }

    struct AccountLiquidityLocalVars {
        uint256 tokensToDenom;
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
    }

    function getAccountLiquidity(
        address account,
        address cToken,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) public view override returns (uint256, uint256) {
        CToken[] memory assets = accountAssets[account];
        AccountLiquidityLocalVars memory vars;

        // calculation for all the asset use having
        for (uint256 i = 0; i < assets.length; i++) {
            CToken asset = assets[i];
            (
                uint256 cTokenBalance,
                uint256 borrowBalance,
                uint256 exchangeRate
            ) = asset.getAccountSnapshot(account);
            vars.tokensToDenom = collateralFactor * exchangeRate * 1;
            vars.sumCollateral += cTokenBalance * vars.tokensToDenom;
            vars.sumBorrowPlusEffects += 1 * borrowBalance;

            if (asset == CToken(cToken)) {
                //Redeem Effects
                vars.sumBorrowPlusEffects += vars.tokensToDenom * redeemTokens;

                //Borrow Effects
                vars.sumBorrowPlusEffects += 1 * borrowAmount;
            }
        }

        //Check for underflow
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

    ///
    /// @param cToken cToken  to redeem
    /// @param redeemer will get the redeemed tokens
    /// @param redeemTokens Number of tokens to redeem
    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemTokens
    ) public view override {
        require(
            markets[cToken].isListed &&
                markets[cToken].accountMembership[redeemer],
            "Redeem not allowed"
        );
        (, uint shortfall) = getAccountLiquidity(
            redeemer,
            cToken,
            redeemTokens,
            0
        );
        require(shortfall == 0, "Insufficient liquidity");
    }

    /// borrower must add the cToken to the market first before borrowing another token
    function addToTheMarket(CToken cToken, address borrower) internal override {
        Market storage marketToJoin = markets[address(cToken)];

        require(marketToJoin.isListed, "Market not listed");
        if (marketToJoin.accountMembership[borrower] == false) {
            marketToJoin.accountMembership[borrower] = true;

            accountAssets[borrower].push(cToken);

            emit AddedToTheMarket(address(cToken), borrower);
        }
    }
}
