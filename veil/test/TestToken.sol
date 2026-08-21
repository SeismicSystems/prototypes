// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ISRC20} from "../src/ISRC20.sol";

/// @title TestToken
/// @notice Minimal SRC20 implementation for testing Veil against a real shielded token
contract TestToken is ISRC20 {
    string public name = "Test Token";
    string public symbol = "TEST";
    uint8 public decimals = 18;

    mapping(address => suint256) private balance;
    mapping(address => mapping(address => suint256)) private allowance;

    function mint(address to, suint256 amount) external {
        unchecked {
            balance[to] += amount;
        }
    }

    function balanceOf() external view returns (uint256) {
        return uint256(balance[msg.sender]);
    }

    function approve(address spender, suint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, suint256 amount) external returns (bool) {
        balance[msg.sender] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }

    function transferFrom(address from, address to, suint256 amount) external returns (bool) {
        suint256 allowed = allowance[from][msg.sender];
        if (allowed != suint256(type(uint256).max)) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balance[from] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }
}
