// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";

contract USDYAllowanceTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public oracle;
    address public owner;
    address public spender;
    address public recipient;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event RewardMultiplierUpdated(uint256 newMultiplier);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        oracle = address(3);
        owner = address(4);
        spender = address(5);
        recipient = address(6);

        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        vm.stopPrank();

        vm.prank(minter);
        token.mint(saddress(owner), suint256(INITIAL_MINT));
    }

    function test_AllowanceWithYield() public {
        uint256 allowanceAmount = 100 * 1e18;
        uint256 yieldIncrement = 0.1e18; // 10% yield

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(allowanceAmount));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Check allowance remains unchanged despite yield
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), allowanceAmount);

        // Calculate shares needed for transfer with yield
        uint256 transferAmount = 50 * 1e18;

        // Transfer using allowance
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance is reduced by token amount, not shares
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), allowanceAmount - transferAmount);

        // Verify recipient received correct amount with yield
        vm.prank(recipient);
        // use 1 wei tolerance to account for integer rounding errors / precision loss
        assertApproxEqAbs(token.balanceOf(saddress(recipient)), transferAmount, 1);
    }

    function test_AllowancePrivacyWithYield() public {
        uint256 allowanceAmount = 100 * 1e18;
        uint256 yieldIncrement = 0.1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(allowanceAmount));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Owner can see allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), allowanceAmount);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), allowanceAmount);

        // Others cannot see allowance (reverts with UnauthorizedView)
        vm.prank(recipient);
        vm.expectRevert(USDY.UnauthorizedView.selector);
        token.allowance(saddress(owner), saddress(spender));
    }

    function test_InfiniteAllowanceWithYield() public {
        // Set infinite allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(type(uint256).max));

        // Add yield multiple times
        vm.startPrank(oracle);
        token.addRewardMultiplier(0.1e18); // +10%
        token.addRewardMultiplier(0.05e18); // +5%
        token.addRewardMultiplier(0.15e18); // +15%
        vm.stopPrank();

        // Transfer using allowance
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(50 * 1e18));

        // Verify allowance remains infinite
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), type(uint256).max);
    }

    function test_AllowanceUpdatesWithMultipleYieldChanges() public {
        uint256 allowanceAmount = 100 * 1e18;
        
        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(allowanceAmount));

        // Multiple yield changes
        vm.startPrank(oracle);
        token.addRewardMultiplier(0.1e18);  // +10%
        token.addRewardMultiplier(0.05e18); // +5%
        vm.stopPrank();

        // Transfer half of allowance
        uint256 transferAmount = allowanceAmount / 2;
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance is reduced correctly
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), allowanceAmount - transferAmount);

        // More yield changes
        vm.prank(oracle);
        token.addRewardMultiplier(0.15e18); // +15%

        // Transfer remaining allowance
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance is zero
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 0);
    }
}