// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

import {ISRC20} from "./ISRC20.sol";

/*//////////////////////////////////////////////////////////////
//                         SRC20 Contract
//////////////////////////////////////////////////////////////*/

contract SRC20 is ISRC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    // Leaks information to public, will replace with encrypted events
    // event Transfer(address indexed from, address indexed to, uint256 amount);
    // event Approval(
    //     address indexed owner,
    //     address indexed spender,
    //     uint256 amount
    // );

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    saddress internal mintTo;
    address public owner;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    // All storage variables that will be mutated must be confidential to
    // preserve functional privacy.
    uint256 public totalSupply;
    mapping(saddress => suint256) internal balance;
    mapping(saddress => mapping(saddress => suint256)) internal _allowance;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, uint8 _decimals, saddress mintTo_, suint256 supply_) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _mint(mintTo_, supply_);
        mintTo = mintTo_;
        owner = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/
    function balanceOf() public view virtual returns (uint256) {
        return uint256(balance[saddress(msg.sender)]);
    }

    function approve(saddress spender, suint256 amount) public virtual returns (bool) {
        _allowance[saddress(msg.sender)][spender] = amount;
        // emit Approval(msg.sender, address(spender), uint256(amount));
        return true;
    }

    function transfer(saddress to, suint256 amount) public virtual returns (bool) {
        //Prevents token transfer outside of OG restaurant
        if (to != mintTo && saddress(msg.sender) != mintTo) {
            revert("Non-transferable outside of Original Restaurant");
        }

        // msg.sender is public information, casting to saddress below doesn't change this
        balance[saddress(msg.sender)] -= amount;
        unchecked {
            balance[to] += amount;
        }
        // emit Transfer(msg.sender, address(to), uint256(amount));
        return true;
    }

    function transferFrom(saddress from, saddress to, suint256 amount) public virtual returns (bool) {
        //same as in above
        if (to != mintTo && from != mintTo) {
            revert("Non-transferable outside of Original Restaurant");
        }

        if (msg.sender != owner) {
            suint256 allowed = _allowance[from][saddress(msg.sender)]; // Saves gas for limited approvals.
            if (allowed != suint256(type(uint256).max)) {
                if (amount > allowed) {
                    revert("not enough allowance");
                }
                _allowance[from][saddress(msg.sender)] = allowed - amount;
            }
        }

        balance[from] -= amount;
        unchecked {
            balance[to] += amount;
        }
        // emit Transfer(msg.sender, address(to), uint256(amount));
        return true;
    }

    function mint(saddress to, suint256 amount) external {
        // For example, restrict minting so that only the owner can mint.
        require(msg.sender == owner, "Only owner can mint tokens");
        _mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/
    function _mint(saddress to, suint256 amount) internal virtual {
        totalSupply += uint256(amount);
        unchecked {
            balance[to] += amount;
        }
        // emit Transfer(address(0), address(to), uint256(amount));
    }

    function allowance(saddress spender) external view returns (uint256) {
        return uint256(_allowance[saddress(msg.sender)][spender]);
    }
}
