// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {SRC20} from "../../src/SRC20.sol";
import {WDGSRC20} from "../../src/WDGSRC20.sol";

contract MockSRC20 is SRC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) SRC20(_name, _symbol, _decimals) {}

    function mint(saddress to, suint256 value) public virtual {
        _mint(to, value);
    }

    function burn(saddress from, suint256 value) public virtual {
        _burn(from, value);
    }
}

contract MockWDGSRC20 is WDGSRC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) WDGSRC20(_name, _symbol, _decimals) {}
}
