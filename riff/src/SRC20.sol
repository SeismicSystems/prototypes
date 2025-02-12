// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

/*//////////////////////////////////////////////////////////////
//                        ISRC20 Interface
//////////////////////////////////////////////////////////////*/

interface ISRC20 {
    /*//////////////////////////////////////////////////////////////
                            METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    /*//////////////////////////////////////////////////////////////
                              ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function balanceOf() external view returns (uint256);
    function approve(saddress spender, suint256 amount) external returns (bool);
    function transfer(saddress to, suint256 amount) external returns (bool);
    function transferFrom(saddress from, saddress to, suint256 amount) external returns (bool);
}

/*//////////////////////////////////////////////////////////////
//                         SRC20 Contract
//////////////////////////////////////////////////////////////*/

abstract contract SRC20 is ISRC20 {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    // All storage variables that will be mutated must be confidential to
    // preserve functional privacy.
    suint256 internal totalSupply;
    mapping(saddress => suint256) internal balance;
    mapping(saddress => mapping(saddress => suint256)) internal allowance;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    function balanceOf() public view virtual returns (uint256) {
        return uint256(balance[saddress(msg.sender)]);
    }

    function approve(saddress spender, suint256 amount) public virtual returns (bool) {
        allowance[saddress(msg.sender)][spender] = amount;
        return true;
    }

    function transfer(saddress to, suint256 amount) public virtual returns (bool) {
        // msg.sender is public information, casting to saddress below doesn't change this
        balance[saddress(msg.sender)] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }

    function transferFrom(saddress from, saddress to, suint256 amount) public virtual returns (bool) {
        suint256 allowed = allowance[from][saddress(msg.sender)]; // Saves gas for limited approvals.
        if (allowed != suint256(type(uint256).max)) {
            allowance[from][saddress(msg.sender)] = allowed - amount;
        }

        balance[from] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function _mint(saddress to, suint256 amount) internal virtual {
        totalSupply += amount;
        unchecked {
            balance[to] += amount;
        }
    }

    function _burn(saddress to, suint256 amount) internal virtual {
        totalSupply -= amount;
        balance[to] -= amount;
    }
}
