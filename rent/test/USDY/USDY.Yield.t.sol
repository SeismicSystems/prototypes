// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract USDYYieldTest is Test {
    USDY public token;
    address public admin;
    address public minter;
    address public oracle;
    address public user1;
    address public user2;
    uint256 public constant BASE = 1e18;
    uint256 public constant INITIAL_MINT = 1000 * 1e18;

    event RewardMultiplierUpdated(uint256 newMultiplier);
    event Transfer(address indexed from, address indexed to, uint256 value);

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

        vm.prank(minter);
        token.mint(saddress(user1), suint256(INITIAL_MINT));
    }

    function test_YieldAccumulationWithSmallIncrements() public {
        uint256[] memory increments = new uint256[](5);
        increments[0] = 0.001e18; // 0.1%
        increments[1] = 0.0005e18; // 0.05%
        increments[2] = 0.002e18; // 0.2%
        increments[3] = 0.0015e18; // 0.15%
        increments[4] = 0.001e18; // 0.1%

        uint256 totalMultiplier = BASE;
        
        // Apply small yield increments
        for(uint256 i = 0; i < increments.length; i++) {
            vm.prank(oracle);
            token.addRewardMultiplier(increments[i]);
            totalMultiplier += increments[i];
        }

        // Calculate expected balance with accumulated yield
        uint256 expectedBalance = (INITIAL_MINT * totalMultiplier) / BASE;

        // Check balance reflects all small yield increments
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), expectedBalance);
    }

    function test_YieldAccumulationWithTransfers() public {
        // Initial transfer to split tokens
        uint256 transferAmount = INITIAL_MINT / 2;
        vm.prank(user1);
        token.transfer(saddress(user2), suint256(transferAmount));

        // Add yield multiple times
        uint256 totalYield = 0;
        uint256[] memory increments = new uint256[](3);
        increments[0] = 0.1e18;  // 10%
        increments[1] = 0.05e18; // 5%
        increments[2] = 0.15e18; // 15%

        for(uint256 i = 0; i < increments.length; i++) {
            vm.prank(oracle);
            token.addRewardMultiplier(increments[i]);
            totalYield += increments[i];
        }

        // Calculate expected balances
        uint256 multiplier = BASE + totalYield;
        uint256 expectedBalance = (transferAmount * multiplier) / BASE;

        // Verify both users' balances reflect accumulated yield
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), expectedBalance);
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), expectedBalance);
    }

    function test_YieldAccumulationWithMinting() public {
        uint256 yieldIncrement = 0.1e18; // 10%
        uint256 mintAmount = 100 * 1e18;

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Mint new tokens
        vm.prank(minter);
        token.mint(saddress(user2), suint256(mintAmount));

        // Calculate expected balance for new mint (should not include previous yield)
        vm.prank(user2);
        uint256 actualBalance = token.balanceOf(saddress(user2));
        assertApproxEqAbs(actualBalance, mintAmount, 1); // Allow 1 wei difference

        // Original holder's balance should include yield
        vm.prank(user1);
        uint256 expectedYieldBalance = (INITIAL_MINT * (BASE + yieldIncrement)) / BASE;
        actualBalance = token.balanceOf(saddress(user1));
        assertApproxEqAbs(actualBalance, expectedYieldBalance, 1); // Allow 1 wei difference
    }

    function test_YieldAccumulationWithBurning() public {
        uint256 yieldIncrement = 0.1e18; // 10%
        uint256 burnAmount = 100 * 1e18;

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Grant burner role to admin for testing
        vm.startPrank(admin);
        token.grantRole(token.BURNER_ROLE(), admin);

        // Burn tokens directly - contract will handle share conversion internally
        token.burn(saddress(user1), suint256(burnAmount));
        vm.stopPrank();

        // Calculate expected remaining balance after burning
        uint256 expectedBalance = (INITIAL_MINT * (BASE + yieldIncrement)) / BASE - burnAmount;

        // Verify remaining balance (allow for 1 wei rounding difference)
        vm.prank(user1);
        uint256 actualBalance = token.balanceOf(saddress(user1));
        assertApproxEqAbs(actualBalance, expectedBalance, 1); // Allow 1 wei difference
    }
}
