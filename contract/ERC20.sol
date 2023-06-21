// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is IERC20 {
    string public name ;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        /// @dev initializing contract with 10 minted tokens
        mint(msg.sender, 10*(10**decimals));
    }

    /// Emitted when value tokens are moved from one account (from) to another (to).
    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance for this transaction");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);   
        return true;  
    }

    /// Moves amount tokens from from to to using the allowance mechanism. amount is then deducted from the caller’s allowance.
    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(allowance[from][msg.sender] >= value, "Insufficient allowance for this transaction");
        require(balanceOf[from] >= value, "Insufficient balance for this transaction");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    /// Sets amount as the allowance of spender over the caller’s tokens.
    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /// Creates amount tokens and assigns them to account, increasing the total supply.
    /// @notice acccount should not be zero address
    function mint(address account, uint256 amount) public {
        require(account != address(0x0), "Zero address account is not allowed");
        balanceOf[account] += amount;
        totalSupply += amount;
        emit Transfer(address(0x0), account, amount);
    }

    /// Destroys amount tokens from account, reducing the total supply.
    /// @notice acccount should not be zero address
    function burn(address account, uint256 amount) public {
        require(account != address(0x0), "Zero address account is not allowed");
        require(balanceOf[account] >= amount, "Insufficient balance");
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0x0), amount);
    }
}
