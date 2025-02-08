// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract USDYPrivacyTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public oracle;
    address public user1;
    address public user2;
    address public observer;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        oracle = address(3);
        user1 = address(4);
        user2 = address(5);
        observer = address(6);

        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        vm.stopPrank();

        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    function test_BalancePrivacyWithYield() public {
        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(0.1e18); // 10% yield

        // Owner can see actual balance with yield
        vm.prank(user1);
        uint256 actualBalance = token.balanceOf(saddress(user1));
        uint256 expectedBalance = (INITIAL_MINT * 11) / 10;
        assertApproxEqAbs(actualBalance, expectedBalance, 1); // Allow 1 wei difference

        // Others see zero
        vm.prank(observer);
        assertEq(token.balanceOf(saddress(user1)), 0);
    }

    function test_TransferPrivacyWithYield() public {
        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(0.1e18); // 10% yield

        uint256 transferAmount = 100 * 1e18;
        
        // Transfer should emit event with actual value
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, transferAmount);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Only recipient can see their balance
        vm.prank(user2);
        uint256 actualBalance = token.balanceOf(saddress(user2));
        assertApproxEqAbs(actualBalance, transferAmount, 1); // Allow 1 wei difference

        // Others (including sender) see zero
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user2)), 0);
        vm.prank(observer);
        assertEq(token.balanceOf(saddress(user2)), 0);
    }

    function test_MintBurnPrivacy() public {
        uint256 amount = 100 * 1e18;

        // Mint new tokens
        vm.prank(minter);
        token.mint(saddress(user2), suint256(amount));

        // Only recipient can see minted amount
        vm.prank(user2);
        uint256 actualBalance = token.balanceOf(saddress(user2));
        assertApproxEqAbs(actualBalance, amount, 1); // Allow 1 wei difference

        // Others see zero
        vm.prank(observer);
        assertEq(token.balanceOf(saddress(user2)), 0);

        // Grant burner role for testing
        vm.startPrank(admin);
        token.grantRole(token.BURNER_ROLE(), admin);

        // Burn tokens
        token.burn(saddress(user2), suint256(amount));
        vm.stopPrank();

        // Balance should be zero after burn
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), 0);
    }

    function test_TotalSupplyPrivacy() public {
        // Total supply should be visible to all
        assertApproxEqAbs(token.totalSupply(), INITIAL_MINT, 1);

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(0.1e18); // 10% yield

        // Total supply should reflect yield
        uint256 expectedSupply = (INITIAL_MINT * 11) / 10;
        assertApproxEqAbs(token.totalSupply(), expectedSupply, 1);

        // Mint more tokens
        vm.prank(minter);
        token.mint(saddress(user2), suint256(100 * 1e18));

        // Total supply should include new mint
        expectedSupply = ((INITIAL_MINT * 11) / 10) + (100 * 1e18);
        assertApproxEqAbs(token.totalSupply(), expectedSupply, 1);
    }
}
