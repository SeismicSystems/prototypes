// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {USDY} from "../../src/USDY.sol";
import {IERC20Errors} from "../../openzeppelin/interfaces/draft-IERC6093.sol";


contract USDYMintTest is Test {
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

    function test_MintIncrementsTotalShares() public {
        uint256 amount = 1 * 1e18;

        // Record initial total shares
        uint256 initialTotalShares = token.totalShares();

        // Mint tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // Verify total shares increased by mint amount
        assertEq(token.totalShares(), initialTotalShares + amount);
    }

    function test_MintIncrementsTotalSupply() public {
        uint256 amount = 1 * 1e18;

        // Record initial total supply
        uint256 initialTotalSupply = token.totalSupply();

        // Mint tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // Verify total supply increased by mint amount
        assertEq(token.totalSupply(), initialTotalSupply + amount);
    }

    function test_MintEmitsTransferEvent() public {
        uint256 amount = 1 * 1e18;

        // Mint should emit Transfer event from zero address
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, amount);
        token.mint(saddress(user1), suint256(amount));
    }

    function test_MintEmitsTransferEventWithTokensNotShares() public {
        uint256 amount = 1000 * 1e18;
        uint256 yieldIncrement = 0.0001e18; // 0.01% yield

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Mint should emit Transfer event with token amount, not shares
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, amount);
        token.mint(saddress(user1), suint256(amount));
    }

    function test_MintSharesAssignedToCorrectAddress() public {
        uint256 amount = 1 * 1e18;

        // Mint tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // Verify shares were assigned to correct address
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), amount);
    }

    function test_MintToZeroAddressReverts() public {
        uint256 amount = 1 * 1e18;

        // Attempt to mint to zero address should revert
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(saddress(address(0)), suint256(amount));
    }

    function test_MintWithYieldCalculatesSharesCorrectly() public {
        uint256 amount = 100 * 1e18;
        uint256 yieldIncrement = 0.1e18; // 10% yield

        // Add yield first
        vm.prank(oracle);
        token.addRewardMultiplier(yieldIncrement);

        // Calculate expected shares
        uint256 expectedShares = (amount * BASE) / (BASE + yieldIncrement);

        // Mint tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // Verify correct number of shares were minted
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), expectedShares);

        // Verify balance shows full token amount (allow 1 wei difference)
        vm.prank(user1);
        uint256 actualBalance = token.balanceOf(saddress(user1));
        assertApproxEqAbs(actualBalance, amount, 1);
    }

    function test_MultipleMints() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 1e18;
        amounts[1] = 50 * 1e18;
        amounts[2] = 75 * 1e18;

        uint256 totalShares = 0;
        uint256 currentMultiplier = BASE;

        // Perform multiple mints with yield changes in between
        for(uint256 i = 0; i < amounts.length; i++) {
            if(i > 0) {
                // Add some yield before subsequent mints
                uint256 yieldIncrement = 0.0001e18 * (i + 1);
                vm.prank(oracle);
                token.addRewardMultiplier(yieldIncrement);
                currentMultiplier += yieldIncrement;
            }

            vm.prank(minter);
            token.mint(saddress(user1), suint256(amounts[i]));

            // Calculate shares for this mint
            totalShares += (amounts[i] * BASE) / currentMultiplier;
        }

        // Calculate expected final balance based on total shares and final multiplier
        uint256 expectedBalance = (totalShares * currentMultiplier) / BASE;

        // Verify final balance reflects total minted amount with yield
        vm.prank(user1);
        uint256 actualBalance = token.balanceOf(saddress(user1));
        assertEq(actualBalance, expectedBalance);

        // Verify shares are calculated correctly
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), totalShares);
    }

    function test_MintPrivacy() public {
        uint256 amount = 100 * 1e18;

        // Mint tokens
        vm.prank(minter);
        token.mint(saddress(user1), suint256(amount));

        // Recipient can see their balance
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), amount);

        // Other users cannot see the balance
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user1)), 0);
    }

    function test_OnlyMinterCanMint() public {
        uint256 amount = 100 * 1e18;

        // Non-minter cannot mint
        bytes32 minterRole = token.MINTER_ROLE();
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(USDY.MissingRole.selector, minterRole, user1));
        token.mint(saddress(user2), suint256(amount));
        vm.stopPrank();

        // Minter can mint
        vm.prank(minter);
        token.mint(saddress(user2), suint256(amount));

        // Verify mint was successful
        vm.prank(user2);
        assertEq(token.balanceOf(saddress(user2)), amount);
    }

    function test_MintZeroAmount() public {
        // Minting zero amount should succeed but not change state
        vm.prank(minter);
        token.mint(saddress(user1), suint256(0));

        // Verify no shares or balance were assigned
        vm.prank(user1);
        assertEq(token.sharesOf(saddress(user1)), 0);
        vm.prank(user1);
        assertEq(token.balanceOf(saddress(user1)), 0);
    }
}