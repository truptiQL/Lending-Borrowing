// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";

abstract contract ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/
    struct Market {
        bool isListed;
        uint256 collateralFactor;
        mapping(address => bool) accountMembership;
    }

    mapping(address => Market) public markets;
    mapping(address => CToken[]) public accountAssets;
    mapping(address => uint256) public accountLiquidity;

    address public admin;

    event MarketAdded(address);

    event MatketExit(address);

    event AddedToTheMarket(address, address);

    function enterMarket(CToken cTokens) external virtual;

    function exitMarket(address cToken) external virtual;

    function borrowAllowed(
        address cToken,
        address borrower,
        uint borrowAmount
    ) external virtual;

    function mintAllowed(address cToken) external view virtual;

    function repayAllowed(address cToken) external view virtual;

    function getAccountLiquidity(
        address account,
        address cToken,
        uint redeemTokens,
        uint borrowAmount
    ) public virtual returns (uint256, uint256);

    function supportMarket(CToken cToken) external virtual;

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint redeemTokens
    ) public virtual;

    function addToTheMarket(CToken ctoken, address account) internal virtual;
}
