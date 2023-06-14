// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./LendingAndBorrowing.sol";

contract Token1 is CToken {

    constructor(string memory _name, string memory _symbol, uint8 _decimal){
        name = _name;
        symbol = _symbol;
        _decimal = _decimal;
    }

}
