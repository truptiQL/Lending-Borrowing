import "./CToken.sol";

contract LendingAndBorrowing {
    struct Market {
        bool isListed;
        uint256 collateralFactor;
        // mapping(address => bool) accountMembership;
    }

    mapping(address => Market) public markets;

    address public admin;
    uint256 collateralFactor = 8 * 1e17;//0.8

    event MarketAdded(address);

    event MatketExit(address);

    event AddedToTheMarket();

    constructor() {
        admin = msg.sender;
    }

    function addMarket(address cToken) public {
        markets[cToken].isListed = true;
        // markets[market].collateralFactor = 0.8;

        emit MarketAdded(cToken);
    }

    function exitMarket(address cToken) public {
        markets[cToken].isListed = false;

        emit MatketExit(cToken);
    }

    function currentExchangeRate() public returns(uint8) {
        return 1;
    }

    function isUnderwater(
        CToken cToken,
        uint256 totalBorrows
    ) public returns(bool) {
        // totalcollateral - totalborrows

        return((cToken.totalSupply() * collateralFactor) < totalBorrows);
    }
}
