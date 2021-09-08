// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

// Third-party interface imports.
import "./IBEP20.sol";

// Third-party library imports.
import "./Address.sol";
import "./Context.sol";
import "./SafeMath.sol";


contract Token is Context, IBEP20
{
    using Address  for address;
    using SafeMath for uint256;
    
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    string private  _name        = "TestToken";
    string private  _symbol      = "TEST";
    uint8 private   _decimals    = 18;
    uint256 private _totalSupply = 1000000000000 * (10 ** _decimals);
    
    constructor()
    {
        _balances[_msgSender()] = _totalSupply;
        
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }
    
    function totalSupply() public view override returns (uint256)
    {
        return _totalSupply;
    }

    function decimals() public view override returns (uint8)
    {
        return _decimals;
    }

    function symbol() public view override returns (string memory)
    {
        return _symbol;
    }

    function name() public view override returns (string memory)
    {
        return _name;
    }

    function getOwner() public pure override returns (address)
    {
        return address(0);
    }

    function balanceOf(address account) public view override returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool)
    {
        require(
            balanceOf(_msgSender()) >= amount,
            "insufficient balance to transfer this amount"
        );
        
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        _balances[recipient]    = _balances[recipient].add(amount);
        
        emit Transfer(_msgSender(), recipient, amount);
        
        return true;
    }

    function allowance(address _owner, address spender) public view override returns (uint256)
    {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool)
    {
        _allowances[_msgSender()][spender] = amount;
        
        emit Approval(_msgSender(), spender, amount);
        
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool)
    {
        require(
            balanceOf(sender) >= amount,
            "insufficient balance to transfer this amount"
        );
        
        require(
            allowance(sender, _msgSender()) >= amount,
            "allowance is too low to transfer this amount"
        );
        
        _balances[sender]    = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        
        emit Transfer(sender, recipient, amount);
        
        return true;   
    }
}
