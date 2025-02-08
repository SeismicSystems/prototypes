// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";


contract USDYBalanceAndSharesTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public oracle;
    address public user1;
    address public user2;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event RewardMultiplierUpdated(uint256 newMultiplier);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        oracle = address(3);
        user1 = address(4);
        user2 = address(5);

        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        vm.stopPrank();
    }

    function test_BalanceReturnsTokensNotShares() public {
        uint256 tokensAmount = 10 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Mint tokens first
        vm.prank(minter);
        token.mint(saddress(user1), suint256(tokensAmount));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Check balance reflects tokens with yield
        vm.prank(user1);
        assertEq(
            token.balanceOf(saddress(user1)), 
            (tokensAmount * (BASE + yieldIncrement)) / BASE
        );
    }

    function test_ZeroBalanceAndSharesForNewAccounts() public {
        // Check balance
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), 0);

        // Check shares
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), 0);
    }

    function test_SharesUnchangedWithYield() public {
        uint256 sharesAmount = 1 * 1e18;

        // Mint initial shares
        vm.prank(minter);
        token.mint(saddress(user1), suint256(sharesAmount));

        // Record initial shares
        vm.prank(user1);
        uint256 initialShares = token.sharesOf(saddress(user1));

        // Add yield multiple times
        vm.startPrank(oracle);
        token.addRewardMultiplier(0.0001e18); // +0.01%
        token.addRewardMultiplier(0.0002e18); // +0.02%
        token.addRewardMultiplier(0.0003e18); // +0.03%
        vm.stopPrank();

        // Verify shares remain unchanged
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialShares);
    }

    function test_SharesPrivacy() public {
        uint256 amount = 100 * 1e18;

        // Mint tokens to user1
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // User1 can see their own shares
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), amount);

        // User2 cannot see user1's shares (should see 0)
        vm.prank(user2);
        assertEq(token.sharesOf(saddress(user1)), 0);
    }

    function test_SharesWithTransfers() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 transferAmount = 40 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Mint initial tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(initialAmount));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Calculate shares for transfer
        uint256 transferShares = (transferAmount * BASE) / (BASE + yieldIncrement);

        // Transfer tokens
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Verify shares
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialAmount - transferShares);
        
        vm.prank(user2);
        assertEq(token.sharesOf(saddress(user2)), transferShares);
    }

    function test_SharesWithMintingAfterYield() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 mintAmount = 50 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Mint initial tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(initialAmount));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Mint more tokens
        vm.prank(minter);
        token.mint(saddress(user2), suint256(mintAmount));

        // Verify shares
        // User1's shares should remain unchanged
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialAmount);

        // User2's shares should be calculated with current yield
        vm.prank(user2);
        assertEq(token.sharesOf(saddress(user2)), (mintAmount * BASE) / (BASE + yieldIncrement));
    }

    function test_TotalShares() public {
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 50 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Mint to first user
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount1));

        // Add yield
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Mint to second user
        vm.prank(minter);
        token.mint(saddress(user2), suint256(amount2));

        // Calculate expected total shares
        uint256 shares1 = amount1; // First mint is 1:1
        uint256 shares2 = (amount2 * BASE) / (BASE + yieldIncrement); // Second mint accounts for yield
        uint256 expectedTotalShares = shares1 + shares2;

        // Verify total shares
        assertEq(token.totalShares(), expectedTotalShares);
    }
}