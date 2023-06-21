// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./ComptrollerInterface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Comptroller is ComptrollerInterface, Initializable {
    uint256 collateralFactor;

    function initialize() public initializer {
        admin = msg.sender;
        collateralFactor = 8 * 1e7; //0.8
    }

    function enterMarket(CToken cToken) public override {
        addToTheMarket(cToken, msg.sender);
    }

    function addToTheMarket(CToken cToken, address borrower) internal override {
        Market storage marketToJoin = markets[address(cToken)];

        require(marketToJoin.isListed, "Market not listed");
        if (marketToJoin.accountMembership[borrower] == false) {
            marketToJoin.accountMembership[borrower] = true;

            accountAssets[borrower].push(cToken);

            emit AddedToTheMarket(address(cToken), borrower);
        }
    }

    function supportMarket(CToken cToken) external override {
        require(msg.sender == admin, "only admin can call this function");
        require(!markets[address(cToken)].isListed, "Market already listed");

        cToken.isCToken(); // Exrtra sanity check to ensure that it is really a cToken
        markets[address(cToken)].isListed = true;

        emit MarketAdded(address(cToken));
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
            if (userAssetList[0] == cToken) {
                userAssetList[0] = userAssetList[1];
                delete userAssetList[1];
            } else if (userAssetList[1] == cToken) {
                delete userAssetList[1];
            }

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
        uint256 _collateralFactor = 8 * 1e7;
        // We have only 2 markets currently so summing up their liquidity

        CToken[] memory assets = accountAssets[account];
        AccountLiquidityLocalVars memory vars;
        for (uint256 i = 0; i < assets.length; i++) {
            CToken asset = assets[i];
            (
                uint256 cTokenBalance,
                uint256 borrowBalance,
                uint256 exchangeRate
            ) = asset.getAccountSnapshot(account);
            vars.tokensToDenom = _collateralFactor * exchangeRate * 1;
            vars.sumCollateral += cTokenBalance * vars.tokensToDenom;
            vars.sumBorrowPlusEffects += 1 * borrowBalance;

            if (asset == CToken(cToken)) {
                //Redeem Effects
                vars.sumBorrowPlusEffects += vars.tokensToDenom * redeemTokens;

                //Borrow Effects
                vars.sumBorrowPlusEffects += 1 * borrowAmount;
            }
        }
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

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

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external override {
        require(markets[cToken].isListed, "Market not listed");

        if (!markets[cToken].accountMembership[borrower]) {
            addToTheMarket(CToken(cToken), borrower);
        }

        (, uint shortfall) = getAccountLiquidity(
            borrower,
            cToken,
            0,
            borrowAmount
        );
        require(shortfall == 0, "Insufficient liquidity");
    }

    function mintAllowed(address cToken) external view override {
        require(markets[cToken].isListed, "market not listed");
    }

    function repayAllowed(address cToken) external view override {
        require(markets[cToken].isListed, "market not listed");
    }
}
