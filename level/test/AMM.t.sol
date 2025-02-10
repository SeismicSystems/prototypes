// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {InternalAMM} from "../src/InternalAMM.sol";
import {WDGSRC20} from "../src/WDGSRC20.sol";
import {Level} from "../src/Level.sol";
import {ISRC20} from "../src/SRC20.sol";
import {MockSRC20, MockWDGSRC20} from "./utils/MockSrc20.sol";

// todo: test only owner can swap, only owner can view, correct calcSwapInput

contract TestAMM is Test {
    address ammOwnerAddress = address(0x1);
    WDGSRC20 public WDG;
    MockSRC20 public USDC;
    InternalAMM public amm;

    function setUp() public {
        USDC = new MockSRC20("USDC", "USDC", 18);
        WDG = new MockWDGSRC20("WDG", "WDG", 18);

        vm.prank(ammOwnerAddress);
        amm = new InternalAMM(address(WDG), address(USDC));

        WDG.setTrustedDePinServiceAddress(ammOwnerAddress);
        WDG.setTrustedAMMAddress(address(amm));

        vm.prank(ammOwnerAddress);
        WDG.setTransferUnlockTime(suint(7100));

        vm.prank(ammOwnerAddress);
        WDG.mint(saddress(ammOwnerAddress), suint(1000 ether));
        vm.prank(ammOwnerAddress);
        USDC.mint(saddress(ammOwnerAddress), suint(1000 ether));

        vm.prank(ammOwnerAddress);
        WDG.approve(saddress(amm), suint(1000 ether));
        vm.prank(ammOwnerAddress);
        USDC.approve(saddress(amm), suint(1000 ether));

        vm.prank(ammOwnerAddress);
        amm.addLiquidity(suint(1000 ether), suint(1000 ether), ammOwnerAddress);

        assertEq(amm.owner(), ammOwnerAddress, "Owner should be set");
    }

    function testOnlyOwnerView() public {
        address user1 = address(0x2);
        vm.prank(ammOwnerAddress);
        WDG.mint(saddress(user1), suint(100));

        vm.prank(user1);
        vm.expectRevert();
        amm.calcSwapInput(address(USDC), suint(10));
    }

    function testOnlyOwnerSwap() public {
        address user2 = address(0x3);
        vm.prank(ammOwnerAddress);
        WDG.mint(saddress(user2), suint(100));

        vm.prank(user2);
        vm.expectRevert();
        amm.swap(saddress(WDG), suint(10));

        vm.prank(user2);
        vm.expectRevert();
        amm.swapOut(saddress(USDC), suint(10));
    }

    function testSwap() public {
        // check swap rate is correct
        vm.prank(ammOwnerAddress);
        WDG.mint(saddress(ammOwnerAddress), suint(250 ether));

        vm.prank(ammOwnerAddress);
        amm.swap(saddress(WDG), suint(250 ether)); // should give back 20 usdc

        vm.prank(ammOwnerAddress);
        suint256 usdcBal = suint256(USDC.balanceOf());
        assertTrue(usdcBal == suint256(200 ether), "Swap amount incorrect.");
    }

    function testSwapOut() public {
        vm.prank(ammOwnerAddress);
        WDG.mint(saddress(ammOwnerAddress), suint256(200));

        vm.prank(ammOwnerAddress);
        amm.swapOut(saddress(USDC), suint256(100));

        vm.prank(ammOwnerAddress);
        suint256 usdcBal = suint256(USDC.balanceOf());
        assertTrue(usdcBal == suint256(100), "Does not swap to correct amount.");

        // must revert if not enough balance for swap.
        vm.prank(ammOwnerAddress);
        vm.expectRevert();
        amm.swapOut(saddress(USDC), suint(101));
    }
}
