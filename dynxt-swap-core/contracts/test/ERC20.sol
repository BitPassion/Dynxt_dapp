pragma solidity =0.5.16;

import '../DYNXTERC20.sol';

contract ERC20 is DYNXTERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
