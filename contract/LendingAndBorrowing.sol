// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./LendingAndBorrowingInterface.sol";

contract LendingAndBorrowing is LendingAndBorrowingInterface {
    constructor() {
        admin = msg.sender;
    }

    function enterMarket(address cToken) public override {
        markets[cToken].isListed = true;

        emit MarketAdded(cToken);
    }

    function exitMarket(address cToken) public override {
        require(markets[cToken].isListed, "Market is not there");
        markets[cToken].isListed = false;

        emit MatketExit(cToken);
    }

    function isUnderwater(
        address cToken,
        uint256 totalBorrows
    ) external view override returns (bool) {
        // totalcollateral - totalborrows

        return ((CToken(cToken).totalSupply() * collateralFactor) <
            totalBorrows);
    }

    function redeemAllowed(
        address cToken,
        address redeemer
    ) external view override returns (bool) {
        
        return (markets[cToken].isListed &&
            markets[cToken].accountMembership[redeemer]);
    }

    function borrowAllowed(
        address cToken
    ) external view override returns (bool) {
        return (markets[cToken].isListed);
    }

    function addToTheMarket(address cToken, address account) external override {
        Market storage marketToJoin = markets[cToken];

        require(marketToJoin.isListed, "Market not listed");
        if (marketToJoin.accountMembership[account] == false) {
            marketToJoin.accountMembership[account] = true;
        }

        emit AddedToTheMarket(cToken, account);
    }
}
