// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract USDYTransferTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public user1;
    address public user2;
    address public spender;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        admin = vm.addr(1);
        minter = vm.addr(2);
        user1 = vm.addr(3);
        user2 = vm.addr(4);
        spender = vm.addr(5);

        // Start admin context
        vm.startPrank(admin);
        
        // Deploy and setup roles
        token = new USDY(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        
        vm.stopPrank();

        // Mint initial tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    function test_TransferEmitsEvent() public {
        uint256 amount = 100e18;
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, amount); // Changed from 0 to actual amount
        token.transfer(saddress(user2), suint256(amount));
    }

    function test_TransferFromEmitsEvent() public {
        uint256 amount = 100e18;
        
        vm.prank(user1);
        token.approve(saddress(spender), suint256(amount));
        
        vm.prank(spender);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, amount); // Changed from 0 to actual amount
        token.transferFrom(saddress(user1), saddress(user2), suint256(amount));
    }
} 