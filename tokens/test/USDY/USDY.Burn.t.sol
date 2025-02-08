// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../openzeppelin/interfaces/draft-IERC6093.sol";


contract USDYBurnTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public burner;
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
        burner = address(3);
        oracle = address(4);
        user1 = address(5);
        user2 = address(6);

        token = new USDY(admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.ORACLE_ROLE(), oracle);
        vm.stopPrank();

        // Initial mint for testing burns
        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    function test_BurnDecrementsAccountShares() public {
        uint256 burnAmount = 1 * 1e18;

        // Record initial shares
        vm.prank(user1);
        uint256 initialShares = token.sharesOf(saddress(user1));

        // Burn tokens
        vm.prank(burner);
        token.burn(saddress(user1), suint256(burnAmount));

        // Verify shares were reduced
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialShares - burnAmount);
    }

    function test_BurnDecrementsTotalShares() public {
        uint256 burnAmount = 1 * 1e18;

        // Record initial total shares
        uint256 initialTotalShares = token.totalShares();

        // Burn tokens
        vm.prank(burner);
        token.burn(saddress(user1), suint256(burnAmount));

        // Verify total shares were reduced
        assertEq(token.totalShares(), initialTotalShares - burnAmount);
    }

    function test_BurnFromZeroAddressReverts() public {
        uint256 burnAmount = 1 * 1e18;

        // Attempt to burn from zero address should revert
        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.burn(saddress(address(0)), suint256(burnAmount));
    }

    function test_BurnExceedingBalanceReverts() public {
        // Get current balance
        vm.prank(user1);
        uint256 balance = token.balanceOf(saddress(user1));
        uint256 burnAmount = balance + 1;

        // Attempt to burn more than balance should revert
        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, balance, burnAmount));
        token.burn(saddress(user1), suint256(burnAmount));
    }

    function test_BurnEmitsTransferEvent() public {
        uint256 burnAmount = 1 * 1e18;

        // Burn should emit Transfer event to zero address
        vm.prank(burner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), burnAmount);
        token.burn(saddress(user1), suint256(burnAmount));
    }

    function test_BurnEmitsTransferEventWithTokensNotShares() public {
        uint256 burnAmount = 1000 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Burn should emit Transfer event with token amount, not shares
        vm.prank(burner);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), burnAmount);
        token.burn(saddress(user1), suint256(burnAmount));
    }

    function test_BurnWithYieldCalculatesSharesCorrectly() public {
        uint256 burnAmount = 100 * 1e18;
        uint256 yieldIncrement = 0.1e18; // 10% yield

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Calculate expected shares to burn
        uint256 sharesToBurn = (burnAmount * BASE) / (BASE + yieldIncrement);

        // Record initial shares
        vm.prank(user1);
        uint256 initialShares = token.sharesOf(saddress(user1));

        // Burn tokens
        vm.prank(burner);
        token.burn(saddress(user1), suint256(burnAmount));

        // Verify correct number of shares were burned
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialShares - sharesToBurn);
    }

    function test_BurnZeroAmount() public {
        // Initial state check
        vm.prank(user1);
        uint256 initialShares = token.sharesOf(saddress(user1));
        vm.prank(user1);
        uint256 initialBalance = token.balanceOf(saddress(user1));

        // Burn zero amount
        vm.prank(burner);
        token.burn(saddress(user1), suint256(0));

        // Verify shares and balance remain unchanged
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), initialShares);
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), initialBalance);
    }

    function test_MultipleBurns() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 1e18;
        amounts[1] = 50 * 1e18;
        amounts[2] = 75 * 1e18;

        // Get initial shares after setup mint
        vm.prank(user1);
        uint256 totalShares = token.sharesOf(saddress(user1));
        uint256 currentMultiplier = BASE;

        // Perform multiple burns with yield changes in between
        for(uint256 i = 0; i < amounts.length; i++) {
            if(i > 0) {
                // Add some yield before subsequent burns
                uint256 yieldIncrement = 0.0001e18 * (i + 1);
                vm.prank(oracle);
                token.addRewardMultiplier(yieldIncrement);
                currentMultiplier += yieldIncrement;
            }

            // Calculate shares to burn for this amount
            uint256 sharesToBurn = (amounts[i] * BASE) / currentMultiplier;
            require(sharesToBurn <= totalShares, "Not enough shares to burn");

            vm.prank(burner);
            token.burn(saddress(user1), suint256(amounts[i]));

            // Update remaining shares
            totalShares -= sharesToBurn;
        }

        // Calculate expected final balance based on remaining shares and final multiplier
        uint256 expectedBalance = (totalShares * currentMultiplier) / BASE;

        // Verify final balance
        vm.prank(user1);
        uint256 actualBalance = token.balanceOf(saddress(user1));
        assertEq(actualBalance, expectedBalance);

        // Verify shares are calculated correctly
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), totalShares);
    }

    function test_BurnPrivacy() public {
        uint256 burnAmount = 100 * 1e18;

        // Record initial balance (only visible to owner)
        vm.prank(user1);
        uint256 initialBalance = token.balanceOf(saddress(user1));

        // Burn tokens
        vm.prank(burner);
        token.burn(saddress(user1), suint256(burnAmount));

        // Owner can see reduced balance
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), initialBalance - burnAmount);

        // Other users still see zero
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user1)), 0);
    }

    function test_OnlyBurnerCanBurn() public {
        uint256 amount = 100 * 1e18;

        // Non-burner cannot burn
        bytes32 burnerRole = token.BURNER_ROLE();
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, burnerRole, user2));
        token.burn(saddress(user1), suint256(amount));

        // Burner can burn
        vm.prank(burner);
        token.burn(saddress(user1), suint256(amount));

        // Verify burn was successful
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), INITIAL_MINT - amount);
    }
}