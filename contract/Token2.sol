// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./LendingAndBorrowing.sol";

contract Token2 is CToken {
   constructor(string memory _name, string memory _symbol, uint8 _decimals, address _LendingAndBorrowing){
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        LendingAndBorrowing = _LendingAndBorrowing;
    }
}
