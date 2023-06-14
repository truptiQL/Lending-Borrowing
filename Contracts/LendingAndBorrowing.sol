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
        // markets[market].collateralFactor = 0.8;

        emit MarketAdded(cToken);
    }

    function exitMarket(address cToken) public override {
        markets[cToken].isListed = false;

        emit MatketExit(cToken);
    }

    function currentExchangeRate() public override returns (uint8) {
        return 1;
    }

    function isUnderwater(
        address cToken,
        uint256 totalBorrows
    ) external override returns (bool) {
        // totalcollateral - totalborrows

        return ((CToken(cToken).totalSupply() * collateralFactor) < totalBorrows);
    }

    function redeemAllowed(address cToken, address redeemer) external override returns(bool){
        return (markets[cToken].isListed && markets[cToken].accountMembership[redeemer]);
    }

    function borrowAllowed(address cToken) external override returns(bool) {
        return (markets[cToken].isListed);
    }
}
