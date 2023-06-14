// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./CToken.sol";
import "./LendingAndBorrowing.sol";

contract Token1 is CToken {
    function price() public returns (uint8) {
        return 1;
    }

    



}
