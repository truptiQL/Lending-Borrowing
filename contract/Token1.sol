// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./LendingAndBorrowing.sol";

contract Token1 is CToken {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _LendingAndBorrowing
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        LendingAndBorrowing = _LendingAndBorrowing;
    }

    function mint(uint256 NoOfTokens, address minter) public {
        mint(NoOfTokens, minter);
    }

    function redeem(
        address redeemer,
        uint256 tokens,
        address underlying
    ) public {
        redeemTokens(redeemer, tokens, underlying);
    }

    function BorrowTokens(
        address borrower,
        uint256 borrowAmount,
        address underlying
    ) public {
        borrow(borrower, borrowAmount, underlying);
    }

    function RepayBorrows(
        address borrower,
        uint256 repayAmount,
        address underlying
    ) public {
        repayBorrow(borrower, repayAmount, underlying);
    }
}
