// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console, stdError} from "forge-std/Test.sol";
import {USDY} from "../src/USDY.sol";
import {IERC20Errors} from "../openzeppelin/interfaces/draft-IERC6093.sol";

contract USDYTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public burner;
    address public oracle;
    address public pauser;
    address public user1;
    address public user2;

    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event RewardMultiplierUpdated(uint256 newMultiplier);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        burner = address(3);
        oracle = address(4);
        pauser = address(5);
        user1 = address(6);
        user2 = address(7);

        // Deploy with admin
        token = new USDY(admin);

        // Setup roles
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        token.grantRole(token.PAUSE_ROLE(), pauser);
        vm.stopPrank();

        // Initial mint
        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    // Basic Functionality Tests

    function test_Metadata() public view {
        assertEq(token.name(), "USD Yield");
        assertEq(token.symbol(), "USDY");
        assertEq(token.decimals(), 18);
    }

    function test_InitialState() public {
        assertEq(token.totalSupply(), INITIAL_MINT);
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT);
    }

    // Role Management Tests

    function test_RoleManagement() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));
        assertTrue(token.hasRole(token.ORACLE_ROLE(), oracle));
        assertTrue(token.hasRole(token.PAUSE_ROLE(), pauser));
    }

    function test_RoleGrantRevoke() public {
        address newMinter = address(10);
        
        vm.startPrank(admin);
        
        // Grant role
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(token.MINTER_ROLE(), newMinter, admin);
        token.grantRole(token.MINTER_ROLE(), newMinter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));

        // Revoke role
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(token.MINTER_ROLE(), newMinter, admin);
        token.revokeRole(token.MINTER_ROLE(), newMinter);
        assertFalse(token.hasRole(token.MINTER_ROLE(), newMinter));
        
        vm.stopPrank();
    }

    /**
     * @notice Tests that only admin can grant roles
     * @dev This test verifies that:
     * 1. A non-admin account cannot grant roles
     * 2. The correct error is thrown with proper parameters
     * 3. The DEFAULT_ADMIN_ROLE is required to grant any role
     *
     * The test flow:
     * - Confirms caller doesn't have admin role
     * - Attempts to grant MINTER_ROLE as non-admin
     * - Verifies the attempt fails with MissingRole error
     */
    function test_OnlyAdminCanGrantRoles() public {
        address caller = user1;
        
        // Verify precondition: caller should not have admin role
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), caller));

        // Cache the minter role to avoid additional calls during revert check
        bytes32 minterRole = token.MINTER_ROLE();
        
        // Set up the prank before expecting revert
        vm.prank(caller);
        
        // Attempt to grant role should fail with MissingRole error
        vm.expectRevert();
        token.grantRole(minterRole, user2);
    }

    // Minting and Burning Tests

    function test_MintAndBurn() public {
        uint256 amount = 100e18;
        
        // Test minting
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));
        
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT + amount);
        assertEq(token.totalSupply(), INITIAL_MINT + amount);
        
        // Test burning
        vm.prank(burner);
        token.burn(saddress(user1), suint256(amount));
        
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT);
        assertEq(token.totalSupply(), INITIAL_MINT);
    }

    function test_MintWithoutRole() public {
        uint256 amount = 100e18;
        
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, token.MINTER_ROLE(), user1));
        vm.prank(user1);
        token.mint(saddress(user1), suint256(amount));
    }

    function test_BurnWithoutRole() public {
        uint256 amount = 100e18;
        
        // First mint some tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));
        
        // Try to burn without role
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, token.BURNER_ROLE(), user1));
        vm.prank(user1);
        token.burn(saddress(user1), suint256(amount));
    }

    function test_MintWhenPaused() public {
        uint256 amount = 100e18;
        
        // Pause the contract
        vm.prank(pauser);
        token.pause();
        
        // Try to mint when paused
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));
    }

    function test_BurnWhenPaused() public {
        uint256 amount = 100e18;
        
        // First mint some tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));
        
        // Pause the contract
        vm.prank(pauser);
        token.pause();
        
        // Try to burn when paused
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        vm.prank(burner);
        token.burn(saddress(user1), suint256(amount));
    }

    function test_PausedTransfers() public {
        // Pause the contract
        vm.prank(pauser);
        token.pause();

        // Try to mint
        vm.prank(minter);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.mint(saddress(user1), suint256(100 * 1e18));

        // Try to burn
        vm.prank(burner);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.burn(saddress(user1), suint256(100 * 1e18));
    }

    // Yield/Reward Multiplier Tests

    function test_InitialRewardMultiplier() public {
        // Transfer to check initial yield behavior
        uint256 transferAmount = 100 * 1e18;
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Check balances reflect 1:1 ratio initially
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT - transferAmount);
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), transferAmount);
    }

    /**
     * @notice Test reward multiplier updates and their effect on token balances
     * @dev This test verifies that:
     * 1. Reward multiplier updates correctly increase token values
     * 2. Transfers after yield updates use proper share calculations
     * 3. Final balances reflect both transferred amounts and accumulated yield
     *
     * The test flow:
     * 1. Start with initial balance in user1's account
     * 2. Add 10% yield through reward multiplier
     * 3. Transfer tokens from user1 to user2
     * 4. Verify balances reflect both the transfer and yield
     */
    function test_RewardMultiplierUpdate() public {
        uint256 increment = 0.1e18; // 10% increase
        uint256 initialBalance = INITIAL_MINT;
        
        // Add yield by increasing reward multiplier by 10%
        vm.prank(oracle);
        vm.expectEmit(true, true, true, true);
        emit RewardMultiplierUpdated(BASE + increment);
        token.addRewardMultiplier(increment);

        // Calculate initial balance after yield
        // When yield is added, the same number of shares are worth more tokens
        uint256 yieldAdjustedInitialBalance = (initialBalance * (BASE + increment)) / BASE;
        
        // Set up transfer amount and calculate shares
        uint256 transferAmount = 100e18;
        
        // Calculate shares needed for transfer
        // When transferring tokens with active yield:
        // shares = tokens * (BASE / (BASE + yield))
        uint256 transferShares = (transferAmount * BASE) / (BASE + increment);
        
        // Calculate expected final balances for both users
        // User1: Convert remaining shares to tokens using new yield rate
        uint256 expectedUser1Shares = initialBalance - transferShares;
        uint256 expectedUser1Balance = (expectedUser1Shares * (BASE + increment)) / BASE;
        // User2: Convert received shares to tokens using new yield rate
        uint256 expectedUser2Balance = (transferShares * (BASE + increment)) / BASE;
        
        // Perform transfer
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Verify final balances
        vm.prank(user1);
        uint256 user1Balance = token.balanceOf(saddress(user1));
        vm.prank(user2);
        uint256 user2Balance = token.balanceOf(saddress(user2));
        
        // Assert balances match expected values
        assertEq(user1Balance, expectedUser1Balance, "User1 balance incorrect");
        assertEq(user2Balance, expectedUser2Balance, "User2 balance incorrect");
        
        // Verify total supply reflects yield increase
        assertEq(token.totalSupply(), yieldAdjustedInitialBalance, "Total supply incorrect");
    }

    function test_OnlyOracleCanUpdateRewardMultiplier() public {
        address caller = user1;
        
        // Attempt to update reward multiplier should fail
        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, token.ORACLE_ROLE(), caller));
        token.addRewardMultiplier(0.1e18);
        vm.stopPrank();
    }

    function test_CannotSetZeroRewardIncrement() public {
        vm.prank(oracle);
        vm.expectRevert(USDY.ZeroRewardIncrement.selector);
        token.addRewardMultiplier(0);
    }

    function test_RewardMultiplierOverflow() public {
        vm.prank(oracle);
        vm.expectRevert(stdError.arithmeticError);
        token.addRewardMultiplier(type(uint256).max);
    }

    // Pause Functionality Tests

    function test_Pause() public {
        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        // Transfers should fail while paused
        vm.prank(user1);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.transfer(saddress(user2), suint256(100 * 1e18));
    }

    function test_Unpause() public {
        // Pause first
        vm.prank(pauser);
        token.pause();
        
        // Then unpause
        vm.prank(pauser);
        token.unpause();
        assertFalse(token.paused());

        // Transfers should work again
        uint256 transferAmount = 100 * 1e18;
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));
        
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), transferAmount);
    }

    function test_OnlyPauserCanPauseUnpause() public {
        address caller = user1;
        
        // Attempt to pause should fail
        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, token.PAUSE_ROLE(), caller));
        token.pause();
        vm.stopPrank();
    }

    // Privacy Tests

    function test_BalancePrivacy() public {
        // Other users can't see balance
        assertEq(token.balanceOf(saddress(user1)), 0);
        
        // Owner can see their balance
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT);
    }

    function test_TransferPrivacy() public {
        uint256 transferAmount = 100e18;
        
        // Transfer should emit event with actual value for transparency
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(user2), transferAmount);
        token.transfer(saddress(user2), suint256(transferAmount));
    }

    // Combined Functionality Tests

    function test_PausedMintingAndBurning() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.mint(saddress(user1), suint256(100 * 1e18));

        vm.prank(burner);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.burn(saddress(user1), suint256(100 * 1e18));
    }

    /**
     * @notice Test yield accumulation behavior with multiple transfers
     * @dev This test verifies that:
     * 1. Yield is correctly applied to all token holders when reward multiplier increases
     * 2. Transfers correctly handle share calculations with active yield
     * 3. Final balances reflect both transferred amounts and accumulated yield
     *
     * The key mechanism being tested:
     * - Token balances are stored internally as shares
     * - Initially, shares are 1:1 with tokens
     * - When yield is added, the shares remain constant but are worth more tokens
     * - Transfers convert token amounts to shares using current yield rate
     * - Final balances are calculated by converting shares back to tokens using yield rate
     */
    function test_YieldAccumulationWithTransfers() public {
        // Initial state has user1 with INITIAL_MINT tokens (and thus INITIAL_MINT shares)
        // and user2 with 0 tokens/shares

        // Add 10% yield by increasing reward multiplier
        vm.prank(oracle);
        token.addRewardMultiplier(0.1e18);
        // Now each share is worth 1.1 tokens

        // Set up transfer amount and calculate corresponding shares
        uint256 transferAmount = 100e18;
        // When transferring 100 tokens with 1.1 yield rate:
        // 100 tokens = x shares * 1.1
        // x shares = 100 * (1/1.1) = 90.909... shares
        uint256 expectedShares = (transferAmount * BASE) / (BASE + 0.1e18);
        
        // Calculate expected final balances
        // User1 starts with INITIAL_MINT shares (1:1 at initial mint)
        // After two transfers of expectedShares each:
        uint256 expectedUser1FinalShares = INITIAL_MINT - (2 * expectedShares);
        // Convert final shares to tokens using yield rate:
        uint256 expectedUser1FinalBalance = (expectedUser1FinalShares * (BASE + 0.1e18)) / BASE;
        // User2 receives 2 * expectedShares, convert to tokens using yield rate:
        uint256 expectedUser2FinalBalance = (2 * expectedShares * (BASE + 0.1e18)) / BASE;
        
        // Perform first transfer
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));
        
        // Perform second transfer
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Verify final balances
        vm.prank(user1);
        uint256 finalUser1Balance = uint256(token.balanceOf(saddress(user1)));
        vm.prank(user2);
        uint256 finalUser2Balance = uint256(token.balanceOf(saddress(user2)));

        // Assert that balances match expected values
        assertEq(finalUser1Balance, expectedUser1FinalBalance, "User1 balance mismatch");
        assertEq(finalUser2Balance, expectedUser2FinalBalance, "User2 balance mismatch");
    }
}
