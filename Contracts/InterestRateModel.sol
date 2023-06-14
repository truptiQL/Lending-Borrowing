

contract InterestRateModel{
    uint256 public multiplierPerBlock ;
    uint256 public baseRatePerBlock;

    function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        uint256 denominator = cash + borrows - reserves;
        return borrows/denominator;
    }
    function borrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view returns (uint256) {
        return utilizationRate(cash, borrows, reserves ) * multiplierPerBlock * baseRatePerBlock;
    }
    function supplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactor) public view returns (uint256) {
        uint256 BASE = 1e18;
        uint256 oneMinusReserveFactor = BASE - reserveFactor;
        uint256 borrowRate = borrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate * oneMinusReserveFactor / BASE;
        return utilizationRate(cash, borrows, reserves) * rateToPool / BASE;
    }
    
}