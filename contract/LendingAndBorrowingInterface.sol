// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";

abstract contract LendingAndBorrowingInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/
    struct Market {
        bool isListed;
        uint256 collateralFactor;
        mapping(address => bool) accountMembership;
    }

    mapping(address => Market) public markets;

    address public admin;
    uint256 collateralFactor = 8 * 1e17; //0.8

    event MarketAdded(address);

    event MatketExit(address);

    event AddedToTheMarket(address, address);
    


    function enterMarket(address cTokens) external virtual;

    function exitMarket(address cToken) external virtual;

    function redeemAllowed(
        address cToken,
        address redeemer
    ) external virtual returns (bool);

    function isUnderwater(
        address cToken,
        uint256 totalBorrows
    ) external virtual returns (bool);

    function borrowAllowed(address cToken) external virtual returns (bool);

    function addToTheMarket(address ctoken, address account) external virtual;

}
