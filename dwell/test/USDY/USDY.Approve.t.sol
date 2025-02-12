// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract USDYApproveTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public owner;
    address public spender;
    address public observer;
    address public recipient;
    address public oracle;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        admin = address(1);
        minter = address(2);
        owner = address(3);
        spender = address(4);
        observer = address(5);
        recipient = address(6);
        oracle = address(7);
        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        vm.stopPrank();

        // Initial mint for testing approvals
        vm.prank(minter);
        token.mint(saddress(owner), suint256(INITIAL_MINT));
    }

    function test_ApproveFromZeroAddressReverts() public {
        // Set approval amount
        uint256 amount = 1 * 1e18;

        // Attempt to approve tokens from zero address
        // This should revert since zero address cannot approve tokens
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(saddress(spender), suint256(amount));
    }

    function test_ApproveToZeroAddressReverts() public {
        uint256 amount = 1 * 1e18;

        // Try to approve to zero address
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(saddress(address(0)), suint256(amount));
    }

    function test_ApproveEmitsEvent() public {
        uint256 amount = 100e18;
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount);
        token.approve(saddress(spender), suint256(amount));
    }

    function test_ApproveAmount() public {
        uint256 amount = 1 * 1e18;

        // Approve amount
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Check allowance (from owner's view)
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);

        // Check allowance (from spender's view)
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);
    }

    function test_ApproveReplacePreviousAmount() public {
        uint256 amount = 1 * 1e18;

        // First approval
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount + 1));

        // Replace with new amount
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Check new allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);
    }

    function test_ApprovePrivacy() public {
        uint256 amount = 1 * 1e18;

        // Set approval
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Owner can see allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);

        // Other accounts cannot see allowance
        vm.prank(observer);
        vm.expectRevert(USDY.UnauthorizedView.selector);
        token.allowance(saddress(owner), saddress(spender));
    }

    function test_ApproveZeroAmount() public {
        uint256 amount = 1 * 1e18;

        // Initial non-zero approval
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Approve zero amount
        vm.prank(owner);
        token.approve(saddress(spender), suint256(0));

        // Check allowance is zero
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 0);
    }

    function test_ApproveDoesNotRequireBalance() public {
        uint256 largeAmount = INITIAL_MINT * 2;

        // Approve more than balance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(largeAmount));

        // Check allowance is set despite insufficient balance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), largeAmount);
    }

    function test_ApproveTwiceEmitsEvents() public {
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 200 * 1e18;

        // First approval should emit event
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount1);
        token.approve(saddress(spender), suint256(amount1));

        // Second approval should also emit event
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount2);
        token.approve(saddress(spender), suint256(amount2));
    }

    function test_ApproveMultipleSpenders() public {
        address spender2 = address(6);
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 200 * 1e18;

        // Approve different amounts to different spenders
        vm.startPrank(owner);
        token.approve(saddress(spender), suint256(amount1));
        token.approve(saddress(spender2), suint256(amount2));
        vm.stopPrank();

        // Check allowances are set correctly
        vm.prank(owner);
        uint256 allowance1 = token.allowance(saddress(owner), saddress(spender));
        assertEq(allowance1, amount1, "First allowance mismatch");

        vm.prank(owner);
        uint256 allowance2 = token.allowance(saddress(owner), saddress(spender2));
        assertEq(allowance2, amount2, "Second allowance mismatch");
    }

    function test_ApproveMaxUint() public {
        uint256 maxAmount = type(uint256).max;

        // Approve max uint256
        vm.prank(owner);
        token.approve(saddress(spender), suint256(maxAmount));

        // Check allowance is set to max
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), maxAmount);
    }

    function test_ApproveAllowanceIndependentOfBalance() public {
        uint256 amount = 100 * 1e18;

        // Approve amount
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Burn all tokens (should not affect allowance)
        bytes32 burner_role = token.BURNER_ROLE();
        vm.prank(admin);
        token.grantRole(burner_role, admin);
        
        vm.prank(admin);
        token.burn(saddress(owner), suint256(INITIAL_MINT));

        // Verify allowance remains unchanged after burning balance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount, "Allowance changed after burning balance");
    }

    // Transfer From Tests

    function test_TransferFromWithInfiniteAllowance() public {
        uint256 transferAmount = 1 * 1e18;

        // Set infinite allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(type(uint256).max));

        // Record initial allowance
        vm.prank(owner);
        uint256 initialAllowance = token.allowance(saddress(owner), saddress(spender));

        // Transfer should not emit Approval event since allowance is infinite
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance remains infinite
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAllowance);
    }

    function test_TransferFromWithSufficientAllowance() public {
        uint256 transferAmount = 1 * 1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(transferAmount));

        // Record initial balances
        vm.prank(owner);
        uint256 initialOwnerBalance = token.balanceOf(saddress(owner));
        vm.prank(recipient);
        uint256 initialRecipientBalance = token.balanceOf(saddress(recipient));

        // Transfer
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify balances
        vm.prank(owner);
        assertEq(token.balanceOf(saddress(owner)), initialOwnerBalance - transferAmount);
        vm.prank(recipient);
        assertEq(token.balanceOf(saddress(recipient)), initialRecipientBalance + transferAmount);
    }

    function test_TransferFromDecreasesAllowance() public {
        uint256 initialAllowance = 2 * 1e18;
        uint256 transferAmount = 1 * 1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAllowance));

        // Transfer
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance decreased
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAllowance - transferAmount);
    }

    function test_TransferFromRevertsWithInsufficientAllowance() public {
        uint256 allowance = 1 * 1e18;
        uint256 transferAmount = 2 * 1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(allowance));

        // Attempt transfer with insufficient allowance
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowance, transferAmount));
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));
    }

    function test_TransferFromEmitsTransferEvent() public {
        uint256 transferAmount = 1 * 1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(transferAmount));

        // Transfer should emit Transfer event
        vm.prank(spender);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, recipient, transferAmount);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));
    }

    function test_TransferFromRevertsWithInsufficientBalance() public {
        uint256 excessAmount = INITIAL_MINT + 1;

        // Set high allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(excessAmount));

        // Attempt transfer with insufficient balance
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, INITIAL_MINT, excessAmount));
        token.transferFrom(saddress(owner), saddress(recipient), suint256(excessAmount));
    }

    /**
     * @notice Tests that allowances are correctly decreased by token amount (not shares) when yield is active
     * @dev This test verifies that:
     * 1. When yield is active, allowances are tracked in tokens, not shares
     * 2. A transfer of X tokens reduces the allowance by X tokens, regardless of yield
     * 3. The actual transfer uses shares internally for accurate accounting
     * 4. The allowance is fully consumed after the transfer
     */
    function test_TransferFromWithYieldDecreasesAllowanceByTokens() public {
        // Set up test amounts
        uint256 transferAmount = 100 * 1e18;  // Transfer 100 tokens
        uint256 yieldIncrement = 0.0004e18;   // Add 0.04% yield (4 bps)

        // First approve spender to spend transferAmount tokens
        vm.prank(owner);
        token.approve(saddress(spender), suint256(transferAmount));
        
        // Add yield to the system
        // This makes each share worth more tokens, but shouldn't affect allowances
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);
        
        // Perform transfer using allowance
        // Even though shares are worth more tokens now, the allowance should still
        // be decreased by the original token amount
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Verify allowance is reduced by token amount (should be 0 after full use)
        vm.prank(owner);
        uint256 finalAllowance = token.allowance(saddress(owner), saddress(spender));
        assertEq(finalAllowance, 0, "Allowance should be zero after transfer");
    }

    function test_TransferFromPrivacy() public {
        uint256 transferAmount = 1 * 1e18;

        // Set allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(transferAmount));

        // Transfer
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(transferAmount));

        // Owner can see their reduced balance
        vm.prank(owner);
        assertEq(token.balanceOf(saddress(owner)), INITIAL_MINT - transferAmount);

        // Recipient can see their increased balance
        vm.prank(recipient);
        assertEq(token.balanceOf(saddress(recipient)), transferAmount);

        // Other accounts cannot see balances
        vm.prank(observer);
        assertEq(token.balanceOf(saddress(owner)), 0);
        assertEq(token.balanceOf(saddress(recipient)), 0);
    }

    function test_TransferFromZeroAmount() public {
        // Set small allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(1));

        // Check initial balance
        vm.prank(owner);
        uint256 initialBalance = token.balanceOf(saddress(owner));

        // Check allowance (from owner's view)
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 1);

        // Transfer zero amount
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(0));

        // Check balance unchanged
        vm.prank(owner);
        assertEq(token.balanceOf(saddress(owner)), initialBalance);

        // Check allowance unchanged (from owner's view)
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 1);
    }

    function test_IncreaseAllowanceAmount() public {
        uint256 amount = 100 * 1e18;

        // Increase allowance
        vm.prank(owner);
        token.increaseAllowance(saddress(spender), suint256(amount));

        // Check allowance is set correctly
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);

        // Spender can also see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount);
    }

    function test_IncreaseAllowanceAddsToExisting() public {
        uint256 amount = 100 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Increase allowance
        vm.prank(owner);
        token.increaseAllowance(saddress(spender), suint256(amount));

        // Check allowance is increased correctly
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount * 2);
    }

    function test_IncreaseAllowanceEmitsEvent() public {
        uint256 amount = 100e18;
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, amount);
        token.increaseAllowance(saddress(spender), suint256(amount));
    }

    function test_IncreaseAllowanceToZeroAddressReverts() public {
        uint256 amount = 100 * 1e18;

        // Try to increase allowance for zero address
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.increaseAllowance(saddress(address(0)), suint256(amount));
    }

    function test_IncreaseAllowancePrivacy() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 increaseAmount = 100 * 1e18;

        // Set initial approval
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Increase allowance
        vm.prank(owner);
        token.increaseAllowance(saddress(spender), suint256(increaseAmount));

        // Owner can see allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount + increaseAmount);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount + increaseAmount);

        // Other accounts cannot see allowance
        vm.prank(observer);
        vm.expectRevert(USDY.UnauthorizedView.selector);
        token.allowance(saddress(owner), saddress(spender));
    }

    function test_IncreaseAllowanceWithZeroValue() public {
        uint256 initialAmount = 100 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Increase by zero
        vm.prank(owner);
        token.increaseAllowance(saddress(spender), suint256(0));

        // Check allowance remains unchanged
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount);
    }

    function test_IncreaseAllowanceMultipleTimes() public {
        uint256 amount = 100 * 1e18;

        // Multiple increases
        vm.startPrank(owner);
        token.increaseAllowance(saddress(spender), suint256(amount));
        token.increaseAllowance(saddress(spender), suint256(amount / 2));
        token.increaseAllowance(saddress(spender), suint256(amount / 4));
        vm.stopPrank();

        // Check final allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), amount + (amount / 2) + (amount / 4));
    }

    function test_IncreaseAllowanceAfterSpending() public {
        uint256 amount = 100 * 1e18;
        uint256 spendAmount = 40 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Spend some of the allowance
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(spendAmount));

        // Increase allowance
        vm.prank(owner);
        token.increaseAllowance(saddress(spender), suint256(amount));

        // Check new allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), (amount - spendAmount) + amount);
    }

    function test_DecreaseAllowanceRevertsWithoutApproval() public {
        uint256 amount = 1 * 1e18;

        // Try to decrease allowance without prior approval
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, amount));
        token.decreaseAllowance(saddress(spender), suint256(amount));
    }

    function test_DecreaseAllowanceSubtractsAmount() public {
        uint256 initialAmount = 2 * 1e18;
        uint256 decreaseAmount = 1 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Decrease allowance
        vm.prank(owner);
        token.decreaseAllowance(saddress(spender), suint256(decreaseAmount));

        // Check new allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount - decreaseAmount);
    }

    function test_DecreaseAllowanceToZero() public {
        uint256 amount = 1 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(amount));

        // Decrease entire allowance
        vm.prank(owner);
        token.decreaseAllowance(saddress(spender), suint256(amount));

        // Check allowance is zero
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 0);
    }

    function test_DecreaseAllowanceRevertsWhenExceedingAllowance() public {
        uint256 initialAmount = 1 * 1e18;
        uint256 decreaseAmount = 2 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Try to decrease by more than allowed
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, initialAmount, decreaseAmount));
        token.decreaseAllowance(saddress(spender), suint256(decreaseAmount));
    }

    function test_DecreaseAllowanceEmitsEvent() public {
        uint256 initialAmount = 100e18;
        uint256 decreaseAmount = 50e18;
        
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, initialAmount - decreaseAmount);
        token.decreaseAllowance(saddress(spender), suint256(decreaseAmount));
    }

    function test_DecreaseAllowancePrivacy() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 decreaseAmount = 40 * 1e18;

        // Set initial approval
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Decrease allowance
        vm.prank(owner);
        token.decreaseAllowance(saddress(spender), suint256(decreaseAmount));

        // Owner can see allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount - decreaseAmount);

        // Spender can see allowance
        vm.prank(spender);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount - decreaseAmount);

        // Other accounts cannot see allowance
        vm.prank(observer);
        vm.expectRevert(USDY.UnauthorizedView.selector);
        token.allowance(saddress(owner), saddress(spender));
    }

    function test_DecreaseAllowanceWithZeroValue() public {
        uint256 initialAmount = 100 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Decrease by zero
        vm.prank(owner);
        token.decreaseAllowance(saddress(spender), suint256(0));

        // Check allowance remains unchanged
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount);
    }

    function test_DecreaseAllowanceMultipleTimes() public {
        uint256 initialAmount = 100 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Multiple decreases
        vm.startPrank(owner);
        token.decreaseAllowance(saddress(spender), suint256(20 * 1e18));
        token.decreaseAllowance(saddress(spender), suint256(30 * 1e18));
        token.decreaseAllowance(saddress(spender), suint256(10 * 1e18));
        vm.stopPrank();

        // Check final allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), 40 * 1e18);
    }

    function test_DecreaseAllowanceAfterSpending() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 spendAmount = 40 * 1e18;
        uint256 decreaseAmount = 30 * 1e18;

        // Set initial allowance
        vm.prank(owner);
        token.approve(saddress(spender), suint256(initialAmount));

        // Spend some of the allowance
        vm.prank(spender);
        token.transferFrom(saddress(owner), saddress(recipient), suint256(spendAmount));

        // Decrease allowance
        vm.prank(owner);
        token.decreaseAllowance(saddress(spender), suint256(decreaseAmount));

        // Check new allowance
        vm.prank(owner);
        assertEq(token.allowance(saddress(owner), saddress(spender)), initialAmount - spendAmount - decreaseAmount);
    }
}