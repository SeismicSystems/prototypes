// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";


contract USDYPauseTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public burner;
    address public pauser;
    address public user1;
    address public user2;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        burner = address(3);
        pauser = address(4);
        user1 = address(5);
        user2 = address(6);

        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.PAUSE_ROLE(), pauser);
        vm.stopPrank();

        // Initial mint to test transfers
        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    function test_MintingWhenUnpaused() public {
        uint256 amount = 10 * 1e18;

        // Pause and then unpause
        vm.startPrank(pauser);
        token.pause();
        token.unpause();
        vm.stopPrank();

        // Should be able to mint after unpausing
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user2, amount);
        token.mint(saddress(user2), suint256(amount));

        // Verify mint was successful
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), amount);
    }

    function test_MintingWhenPaused() public {
        uint256 amount = 10 * 1e18;

        // Pause
        vm.prank(pauser);
        token.pause();

        // Should not be able to mint while paused
        vm.prank(minter);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.mint(saddress(user2), suint256(amount));
    }

    function test_BurningWhenUnpaused() public {
        uint256 amount = 10 * 1e18;

        // Pause and then unpause
        vm.startPrank(pauser);
        token.pause();
        token.unpause();
        vm.stopPrank();

        // Should be able to burn after unpausing
        vm.prank(burner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), amount);
        token.burn(saddress(user1), suint256(amount));

        // Verify burn was successful
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT - amount);
    }

    function test_BurningWhenPaused() public {
        uint256 amount = 10 * 1e18;

        // Pause
        vm.prank(pauser);
        token.pause();

        // Should not be able to burn while paused
        vm.prank(burner);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.burn(saddress(user1), suint256(amount));
    }

    function test_TransfersWhenUnpaused() public {
        uint256 amount = 10 * 1e18;

        // Pause and then unpause
        vm.startPrank(pauser);
        token.pause();
        token.unpause();
        vm.stopPrank();

        // Should be able to transfer after unpausing
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, amount);
        token.transfer(saddress(user2), suint256(amount));

        // Verify transfer was successful
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), amount);
    }

    function test_TransfersWhenPaused() public {
        uint256 amount = 10 * 1e18;

        // Pause
        vm.prank(pauser);
        token.pause();

        // Should not be able to transfer while paused
        vm.prank(user1);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.transfer(saddress(user2), suint256(amount));
    }

    function test_TransferFromWhenUnpaused() public {
        uint256 amount = 10 * 1e18;

        // Setup approval
        vm.prank(user1);
        token.approve(saddress(user2), suint256(amount));

        // Pause and then unpause
        vm.startPrank(pauser);
        token.pause();
        token.unpause();
        vm.stopPrank();

        // Should be able to transferFrom after unpausing
        vm.prank(user2);
        token.transferFrom(saddress(user1), saddress(user2), suint256(amount));

        // Verify transfer was successful
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), amount);
    }

    function test_TransferFromWhenPaused() public {
        uint256 amount = 10 * 1e18;

        // Setup approval
        vm.prank(user1);
        token.approve(saddress(user2), suint256(amount));

        // Pause
        vm.prank(pauser);
        token.pause();

        // Should not be able to transferFrom while paused
        vm.prank(user2);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.transferFrom(saddress(user1), saddress(user2), suint256(amount));
    }

    function test_PauseUnpauseEvents() public {
        // Test pause event
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true);
        emit Paused(pauser);
        token.pause();

        // Test unpause event
        vm.prank(pauser);
        vm.expectEmit(true, true, true, true);
        emit Unpaused(pauser);
        token.unpause();
    }

    function test_OnlyPauserCanPauseUnpause() public {
        // Non-pauser cannot pause
        vm.startPrank(user1);
        bytes32 pauseRole = token.PAUSE_ROLE();
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, pauseRole, user1));
        token.pause();
        vm.stopPrank();

        // Pause with correct role
        vm.prank(pauser);
        token.pause();

        // Non-pauser cannot unpause
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, pauseRole, user1));
        token.unpause();
        vm.stopPrank();

        // Unpause with correct role
        vm.prank(pauser);
        token.unpause();
    }

    function test_CannotPauseWhenPaused() public {
        // Pause first time
        vm.prank(pauser);
        token.pause();

        // Try to pause again
        vm.prank(pauser);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.pause();
    }

    function test_CannotUnpauseWhenUnpaused() public {
        // Try to unpause when not paused
        vm.prank(pauser);
        vm.expectRevert(USDY.TransferWhilePaused.selector);
        token.unpause();
    }
}