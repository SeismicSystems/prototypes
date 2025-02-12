// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SRC20, UnauthorizedView} from "../src/SRC20.sol";
import {IERC20Errors} from "../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract TestSRC20 is SRC20 {
    constructor(string memory name, string memory symbol) SRC20(name, symbol) {}

    function mint(saddress account, suint256 value) public {
        _mint(account, value);
    }

    function burn(saddress account, suint256 value) public {
        _burn(account, value);
    }
}

contract TestSRC20Decimals is SRC20 {
    uint8 private immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) SRC20(name, symbol) {
        _decimals = decimals_;
    }

    function mint(saddress account, suint256 value) public {
        _mint(account, value);
    }

    function burn(saddress account, suint256 value) public {
        _burn(account, value);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

contract TestSRC20WithEvents is TestSRC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name, string memory symbol) TestSRC20(name, symbol) {}

    function emitTransfer(address from, address to, uint256 value) public virtual override {
        emit Transfer(from, to, value);
    }

    function emitApproval(address owner, address spender, uint256 value) public virtual override {
        emit Approval(owner, spender, value);
    }
}

contract SRC20Test is Test {
    TestSRC20WithEvents public token;
    address public initialHolder;
    address public recipient;
    address public anotherAccount;
    uint256 public initialSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        initialHolder = address(1);
        recipient = address(2);
        anotherAccount = address(3);
        initialSupply = 100 * 10**18; // 100 tokens with 18 decimals

        token = new TestSRC20WithEvents("My Token", "MTKN");
        token.mint(saddress(initialHolder), suint256(initialSupply));
    }

    function test_Metadata() public view {
        assertEq(token.name(), "My Token");
        assertEq(token.symbol(), "MTKN");
        assertEq(token.decimals(), 18);
    }

    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), initialSupply);
    }

    function test_BalanceOf() public {
        // When checking own balance
        vm.prank(initialHolder);
        assertEq(token.balanceOf(saddress(initialHolder)), initialSupply);

        // When checking other's balance (should revert)
        vm.expectRevert(UnauthorizedView.selector);
        token.balanceOf(saddress(initialHolder));
    }

    function test_Transfer() public {
        uint256 transferAmount = 50 * 10**18;
        
        vm.prank(initialHolder);
        token.transfer(saddress(recipient), suint256(transferAmount));

        // Check balances
        vm.prank(initialHolder);
        assertEq(token.balanceOf(saddress(initialHolder)), initialSupply - transferAmount);
        
        vm.prank(recipient);
        assertEq(token.balanceOf(saddress(recipient)), transferAmount);
    }

    function test_TransferFailsForInsufficientBalance() public {
        uint256 transferAmount = initialSupply + 1;
        
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, initialHolder, 0, 0));
        token.transfer(saddress(recipient), suint256(transferAmount));
    }

    function test_TransferFailsForZeroAddress() public {
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(saddress(address(0)), suint256(1));
    }

    function test_Approve() public {
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(initialSupply));

        // Check allowance (visible only to owner or spender)
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), initialSupply);
        
        vm.prank(recipient);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), initialSupply);

        // Check allowance (should revert for others)
        vm.prank(anotherAccount);
        vm.expectRevert(UnauthorizedView.selector);
        token.allowance(saddress(initialHolder), saddress(recipient));
    }

    function test_TransferFrom() public {
        uint256 transferAmount = 50 * 10**18;
        
        // Approve first
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(transferAmount));

        // Transfer using transferFrom
        vm.prank(recipient);
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(transferAmount));

        // Check balances
        vm.prank(initialHolder);
        assertEq(token.balanceOf(saddress(initialHolder)), initialSupply - transferAmount);
        
        vm.prank(anotherAccount);
        assertEq(token.balanceOf(saddress(anotherAccount)), transferAmount);

        // Check allowance is reduced
        vm.prank(recipient);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 0);
    }

    function test_TransferFromFailsWithoutAllowance() public {
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, recipient, 0, 0));
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(1));
    }

    function test_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(saddress(address(0)), suint256(1));
    }

    function test_BurnFromZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.burn(saddress(address(0)), suint256(100));
    }

    function test_BurnExceedingBalanceReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, initialHolder, 0, 0));
        token.burn(saddress(initialHolder), suint256(initialSupply + 1));
    }

    // Transfer Events Tests

    function test_TransferEmitsEvent() public {
        uint256 transferAmount = 50 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(initialHolder, recipient, transferAmount);
        
        vm.prank(initialHolder);
        token.transfer(saddress(recipient), suint256(transferAmount));
    }

    function test_MintEmitsTransferEvent() public {
        uint256 mintAmount = 100 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), recipient, mintAmount);
        
        token.mint(saddress(recipient), suint256(mintAmount));
    }

    function test_BurnEmitsTransferEvent() public {
        uint256 burnAmount = 50 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(initialHolder, address(0), burnAmount);
        
        token.burn(saddress(initialHolder), suint256(burnAmount));
    }

    function test_TransferFromEmitsTransferEvent() public {
        uint256 transferAmount = 50 * 10**18;
        
        // Approve first
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(transferAmount));
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(initialHolder, anotherAccount, transferAmount);
        
        vm.prank(recipient);
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(transferAmount));
    }

    function test_ZeroValueTransferEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(initialHolder, recipient, 0);
        
        vm.prank(initialHolder);
        token.transfer(saddress(recipient), suint256(0));
    }

    // Infinite Approval Tests

    function test_InfiniteApprovalRemainsUnchanged() public {
        // Approve with max uint256
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(type(uint256).max));

        // Do a transferFrom
        vm.prank(recipient);
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(50 * 10**18));

        // Check that allowance is still infinite
        vm.prank(recipient);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), type(uint256).max);
    }

    function test_InfiniteApprovalNoEventOnTransferFrom() public {
        // Setup infinite approval
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(type(uint256).max));

        vm.expectEmit(true, true, false, true);
        emit Transfer(initialHolder, anotherAccount, 50 * 10**18);
        
        vm.prank(recipient);
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(50 * 10**18));
    }

    function test_InfiniteApprovalMultipleTransfers() public {
        uint256 transferAmount = 20 * 10**18;
        
        // Setup infinite approval
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(type(uint256).max));

        // Do multiple transfers
        for(uint256 i = 0; i < 3; i++) {
            vm.prank(recipient);
            token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(transferAmount));

            // Check allowance remains infinite
            vm.prank(recipient);
            assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), type(uint256).max);
        }

        // Verify final balances
        vm.prank(initialHolder);
        assertEq(token.balanceOf(saddress(initialHolder)), initialSupply - (transferAmount * 3));
        
        vm.prank(anotherAccount);
        assertEq(token.balanceOf(saddress(anotherAccount)), transferAmount * 3);
    }

    function test_InfiniteApprovalFailsWithInsufficientBalance() public {
        // Setup infinite approval
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(type(uint256).max));

        // Try to transfer more than balance
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, initialHolder, 0, 0));
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(initialSupply + 1));

        // Allowance should still be infinite
        vm.prank(recipient);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), type(uint256).max);
    }

    // Approve Edge Cases Tests

    function test_ApproveEmitsNoEvent() public {
        // No event expectation since emitApproval is a no-op by default
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(50 * 10**18));
        
        // Verify the approval was still set
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 50 * 10**18);
    }

    function test_ApproveFromZeroAddress() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        token.approve(saddress(recipient), suint256(100));
    }

    function test_ApproveToZeroAddress() public {
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(saddress(address(0)), suint256(100));
    }

    function test_ApproveReplacesExistingValue() public {
        // First approval
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(100));

        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 100);

        // Replace with new value
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(200));

        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 200);
    }

    function test_ApproveZeroValue() public {
        // Initial non-zero approval
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(100));

        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(0));

        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 0);
    }

    function test_ApproveDoesNotRequireBalance() public {
        uint256 largeAmount = initialSupply * 100;
        
        // Approve more than balance
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(largeAmount));

        // Check allowance is set despite insufficient balance
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), largeAmount);

        // But transferFrom should still fail
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, initialHolder, 0, 0));
        token.transferFrom(saddress(initialHolder), saddress(anotherAccount), suint256(largeAmount));
    }

    function test_ApproveTwiceNoEvents() public {
        // No event expectations since emitApproval is a no-op by default
        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(100));

        vm.prank(initialHolder);
        token.approve(saddress(recipient), suint256(200));
        
        // Verify the final approval was set
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(recipient)), 200);
    }
}

contract SRC20DecimalsTest is Test {
    TestSRC20Decimals public token6;
    TestSRC20Decimals public token0;
    address public holder;
    address public recipient;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        holder = address(1);
        recipient = address(2);

        // Create tokens with different decimal configurations
        token6 = new TestSRC20Decimals("Six Decimals", "SIX", 6);
        token0 = new TestSRC20Decimals("Zero Decimals", "ZERO", 0);
    }

    function test_CustomDecimals() public view {
        assertEq(token6.decimals(), 6);
        assertEq(token0.decimals(), 0);
    }

    function test_MintWithSixDecimals() public {
        uint256 amount = 100 * 10**6; // 100 tokens with 6 decimals
        token6.mint(saddress(holder), suint256(amount));

        vm.prank(holder);
        assertEq(token6.balanceOf(saddress(holder)), amount);
        assertEq(token6.totalSupply(), amount);
    }

    function test_MintWithZeroDecimals() public {
        uint256 amount = 100; // 100 tokens with 0 decimals
        token0.mint(saddress(holder), suint256(amount));

        vm.prank(holder);
        assertEq(token0.balanceOf(saddress(holder)), amount);
        assertEq(token0.totalSupply(), amount);
    }

    function test_TransferWithSixDecimals() public {
        uint256 amount = 100 * 10**6; // 100 tokens with 6 decimals
        token6.mint(saddress(holder), suint256(amount));

        vm.prank(holder);
        token6.transfer(saddress(recipient), suint256(50 * 10**6));

        vm.prank(holder);
        assertEq(token6.balanceOf(saddress(holder)), 50 * 10**6);
        
        vm.prank(recipient);
        assertEq(token6.balanceOf(saddress(recipient)), 50 * 10**6);
    }

    function test_TransferWithZeroDecimals() public {
        uint256 amount = 100; // 100 tokens with 0 decimals
        token0.mint(saddress(holder), suint256(amount));

        vm.prank(holder);
        token0.transfer(saddress(recipient), suint256(50));

        vm.prank(holder);
        assertEq(token0.balanceOf(saddress(holder)), 50);
        
        vm.prank(recipient);
        assertEq(token0.balanceOf(saddress(recipient)), 50);
    }

    function test_SmallestUnitTransferSixDecimals() public {
        uint256 amount = 100 * 10**6; // 100 tokens with 6 decimals
        token6.mint(saddress(holder), suint256(amount));

        // Transfer 1 unit (0.000001 token)
        vm.prank(holder);
        token6.transfer(saddress(recipient), suint256(1));

        vm.prank(holder);
        assertEq(token6.balanceOf(saddress(holder)), amount - 1);
        
        vm.prank(recipient);
        assertEq(token6.balanceOf(saddress(recipient)), 1);
    }

    function test_SmallestUnitTransferZeroDecimals() public {
        uint256 amount = 100; // 100 tokens with 0 decimals
        token0.mint(saddress(holder), suint256(amount));

        // Transfer 1 unit (1 whole token for 0 decimals)
        vm.prank(holder);
        token0.transfer(saddress(recipient), suint256(1));

        vm.prank(holder);
        assertEq(token0.balanceOf(saddress(holder)), amount - 1);
        
        vm.prank(recipient);
        assertEq(token0.balanceOf(saddress(recipient)), 1);
    }

    function test_MaxSupplyWithDifferentDecimals() public {
        // Test max supply with 6 decimals
        uint256 maxAmount6 = type(uint256).max;
        token6.mint(saddress(holder), suint256(maxAmount6));
        assertEq(token6.totalSupply(), maxAmount6);

        // Test max supply with 0 decimals
        uint256 maxAmount0 = type(uint256).max;
        token0.mint(saddress(holder), suint256(maxAmount0));
        assertEq(token0.totalSupply(), maxAmount0);
    }

    function test_BurnWithDifferentDecimals() public {
        // Test burning with 6 decimals
        uint256 amount6 = 100 * 10**6;
        token6.mint(saddress(holder), suint256(amount6));
        token6.burn(saddress(holder), suint256(50 * 10**6));
        assertEq(token6.totalSupply(), 50 * 10**6);

        // Test burning with 0 decimals
        uint256 amount0 = 100;
        token0.mint(saddress(holder), suint256(amount0));
        token0.burn(saddress(holder), suint256(50));
        assertEq(token0.totalSupply(), 50);
    }
}

contract SRC20AllowanceTest is Test {
    TestSRC20WithEvents public token;
    address public initialHolder;
    address public spender;
    address public otherAccount;
    uint256 public initialSupply;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        initialHolder = address(1);
        spender = address(2);
        otherAccount = address(3);
        initialSupply = 100 * 10**18;

        token = new TestSRC20WithEvents("My Token", "MTKN");
        token.mint(saddress(initialHolder), suint256(initialSupply));
    }

    // Basic Functionality Tests

    function test_IncreaseAllowance() public {
        uint256 initialAllowance = 100;
        uint256 addedValue = 50;

        // Set initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(initialAllowance));

        vm.prank(initialHolder);
        token.increaseAllowance(saddress(spender), suint256(addedValue));

        // Check new allowance (visible to owner)
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), initialAllowance + addedValue);
    }

    function test_DecreaseAllowance() public {
        uint256 initialAllowance = 100;
        uint256 subtractedValue = 50;

        // Set initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(initialAllowance));

        vm.prank(initialHolder);
        token.decreaseAllowance(saddress(spender), suint256(subtractedValue));

        // Check new allowance (visible to owner)
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), initialAllowance - subtractedValue);
    }

    // Privacy Tests

    function test_IncreaseAllowancePrivacy() public {
        // Set and increase allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));
        
        vm.prank(initialHolder);
        token.increaseAllowance(saddress(spender), suint256(50));

        // Owner can see allowance
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 150);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 150);

        // Other accounts should revert
        vm.prank(otherAccount);
        vm.expectRevert(UnauthorizedView.selector);
        token.allowance(saddress(initialHolder), saddress(spender));
    }

    function test_DecreaseAllowancePrivacy() public {
        // Set and decrease allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));
        
        vm.prank(initialHolder);
        token.decreaseAllowance(saddress(spender), suint256(50));

        // Owner can see allowance
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 50);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 50);

        // Other accounts should revert
        vm.prank(otherAccount);
        vm.expectRevert(UnauthorizedView.selector);
        token.allowance(saddress(initialHolder), saddress(spender));
    }

    // Edge Cases

    function test_DecreaseAllowanceBelowZeroFails() public {
        // Set initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Try to decrease by more than current allowance
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 0));
        token.decreaseAllowance(saddress(spender), suint256(101));

        // Allowance should remain unchanged
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100);
    }

    function test_IncreaseAllowanceToMax() public {
        // Start with some allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Increase to max
        vm.prank(initialHolder);
        token.increaseAllowance(saddress(spender), suint256(type(uint256).max - 100));

        // Check max allowance
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), type(uint256).max);
    }

    function test_MultipleAllowanceUpdates() public {
        // Multiple increases
        vm.startPrank(initialHolder);
        token.approve(saddress(spender), suint256(100));
        token.increaseAllowance(saddress(spender), suint256(50));
        token.increaseAllowance(saddress(spender), suint256(75));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 225);

        // Multiple decreases
        token.decreaseAllowance(saddress(spender), suint256(25));
        token.decreaseAllowance(saddress(spender), suint256(50));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 150);
        vm.stopPrank();
    }

    function test_ZeroValueAllowanceUpdates() public {
        vm.startPrank(initialHolder);
        
        token.increaseAllowance(saddress(spender), suint256(0));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 0);

        // Set non-zero allowance
        token.approve(saddress(spender), suint256(100));

        token.decreaseAllowance(saddress(spender), suint256(0));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100);
        
        vm.stopPrank();
    }

    function test_AllowanceUpdatesWithTransfers() public {
        uint256 transferAmount = 50;
        
        // Setup allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Increase allowance and perform transfer
        vm.prank(initialHolder);
        token.increaseAllowance(saddress(spender), suint256(50));

        vm.prank(spender);
        token.transferFrom(saddress(initialHolder), saddress(otherAccount), suint256(transferAmount));

        // Check remaining allowance
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100); // 150 - 50
    }

    // Additional Edge Cases for Increase/Decrease Allowance

    function test_DecreaseAllowanceBelowZeroReverts() public {
        // Try to decrease allowance when there was no approved amount before
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 0));
        token.decreaseAllowance(saddress(spender), suint256(1));

        // Set initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Try to decrease by more than current allowance
        vm.prank(initialHolder);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 0));
        token.decreaseAllowance(saddress(spender), suint256(101));

        // Allowance should remain unchanged
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100);
    }

    function test_IncreaseAllowanceOverflow() public {
        // Set high initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(type(uint256).max - 1));

        // Try to increase allowance which would cause overflow
        vm.prank(initialHolder);
        vm.expectRevert();  // Should revert on overflow
        token.increaseAllowance(saddress(spender), suint256(2));
    }

    function test_AllowanceUpdatesWithZeroTransfer() public {
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Zero value transfer should NOT decrease allowance
        vm.prank(spender);
        token.transferFrom(saddress(initialHolder), saddress(otherAccount), suint256(0));

        // Allowance should remain unchanged
        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100);
    }

    function test_IncreaseAllowanceWithZeroInitial() public {
        // Increase allowance when there was no approved amount before
        vm.prank(initialHolder);
        token.increaseAllowance(saddress(spender), suint256(100));

        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 100);
    }

    function test_DecreaseAllowanceToZero() public {
        // Set initial allowance
        vm.prank(initialHolder);
        token.approve(saddress(spender), suint256(100));

        // Decrease allowance to exactly zero
        vm.prank(initialHolder);
        token.decreaseAllowance(saddress(spender), suint256(100));

        vm.prank(initialHolder);
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 0);
    }

    function test_ConsecutiveAllowanceUpdates() public {
        vm.startPrank(initialHolder);
        
        // Multiple increases
        token.increaseAllowance(saddress(spender), suint256(50));
        token.increaseAllowance(saddress(spender), suint256(30));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 80);

        // Multiple decreases
        token.decreaseAllowance(saddress(spender), suint256(20));
        token.decreaseAllowance(saddress(spender), suint256(10));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 50);

        // Mix of increases and decreases
        token.increaseAllowance(saddress(spender), suint256(25));
        token.decreaseAllowance(saddress(spender), suint256(15));
        assertEq(token.allowance(saddress(initialHolder), saddress(spender)), 60);

        vm.stopPrank();
    }
}

contract SRC20MetadataTest is Test {
    TestSRC20WithEvents public token;
    string constant NAME = "Test Token";
    string constant SYMBOL = "TST";
    uint8 constant DECIMALS = 18;

    function setUp() public {
        token = new TestSRC20WithEvents(NAME, SYMBOL);
    }

    function test_TokenName() public view {
        assertEq(token.name(), NAME);
    }

    function test_TokenSymbol() public view {
        assertEq(token.symbol(), SYMBOL);
    }

    function test_TokenDecimals() public view {
        assertEq(token.decimals(), DECIMALS);
    }
}

contract SRC20MintBurnTest is Test {
    TestSRC20WithEvents public token;
    address public initialHolder = address(1);
    address public recipient = address(2);
    uint256 public initialSupply = 100;

    function setUp() public {
        token = new TestSRC20WithEvents("Test Token", "TST");
        token.mint(saddress(initialHolder), suint256(initialSupply));
    }

    function test_MintToZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(saddress(address(0)), suint256(1));
    }

    function test_BurnFromZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.burn(saddress(address(0)), suint256(100));
    }

    function test_BurnExceedingBalanceReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, initialHolder, 0, 0));
        token.burn(saddress(initialHolder), suint256(initialSupply + 1));
    }

    function test_MintIncrementsTotalSupply() public {
        uint256 amount = 50;
        uint256 previousSupply = token.totalSupply();
        
        token.mint(saddress(recipient), suint256(amount));
        assertEq(token.totalSupply(), previousSupply + amount);
    }

    function test_BurnDecrementsTotalSupply() public {
        uint256 amount = 50;
        uint256 previousSupply = token.totalSupply();
        
        token.burn(saddress(initialHolder), suint256(amount));
        assertEq(token.totalSupply(), previousSupply - amount);
    }

    function test_MintToExistingBalance() public {
        uint256 amount = 50;
        
        // Need to be the account owner to see the balance
        vm.prank(initialHolder);
        uint256 previousBalance = token.balanceOf(saddress(initialHolder));
        
        token.mint(saddress(initialHolder), suint256(amount));
        
        // Need to be the account owner to see the updated balance
        vm.prank(initialHolder);
        assertEq(token.balanceOf(saddress(initialHolder)), previousBalance + amount);
    }

    function test_BurnEntireBalance() public {
        token.burn(saddress(initialHolder), suint256(initialSupply));
        
        vm.prank(initialHolder);
        (bool success, uint256 balance) = token.safeBalanceOf(saddress(initialHolder));
        assertTrue(success);
        assertEq(balance, 0);
    }

    function test_MintMaxUintValue() public {
        uint256 remainingSupply = type(uint256).max - token.totalSupply();
        // Should not revert
        token.mint(saddress(recipient), suint256(remainingSupply));
        
        // Should revert on next mint due to overflow
        vm.expectRevert();
        token.mint(saddress(recipient), suint256(1));
    }
}
