// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {PermissionedAMM} from "../src/PermissionedAMM.sol";
import {WDGSRC20} from "../src/WDGSRC20.sol";
import {WidgetInterface} from "../src/WidgetInterface.sol";
import {ISRC20} from "../src/SRC20.sol";
import {MockSRC20, MockWDGSRC20} from "./utils/MockSrc20.sol";

contract TestInterface is Test {
    address oracleAddress = address(0x1);
    WDGSRC20 public WDG;
    MockSRC20 public USDC;
    WidgetInterface public service;
    PermissionedAMM public amm;

    function setUp() public {
        USDC = new MockSRC20("USDC", "USDC", 18);
        WDG = new MockWDGSRC20("WDG", "WDG", 18);
        service = new WidgetInterface(address(WDG), address(USDC), oracleAddress, suint(100), suint(7100));

        amm = service.amm();
        // set up the amm
        vm.prank(address(service));
        WDG.mint(saddress(service), suint(1000 ether));
        USDC.mint(saddress(service), suint(1000 ether));

        vm.prank(address(service));
        WDG.approve(saddress(amm), suint(1000 ether));
        vm.prank(address(service));
        USDC.approve(saddress(amm), suint(1000 ether));

        vm.prank(address(service));
        amm.addLiquidity(suint(1000 ether), suint(1000 ether), address(service)); // service balances are 0

        assertEq(amm.owner(), address(service), "Owner should be service");
    }

    function testTransfer() public {
        vm.prank(address(amm));
        uint256 ammBalanceInit = WDG.balanceOf();

        vm.prank(address(service));
        WDG.mint(saddress(service), suint(1 ether));
        vm.prank(address(service));
        WDG.transfer(saddress(amm), suint(1 ether));

        vm.prank(address(amm));
        uint256 ammBalanceFin = WDG.balanceOf();

        assertEq(ammBalanceFin - ammBalanceInit, 1 ether, "Incorrect amount transferred.");
    }

    function testTransferFail() public {
        address user1 = address(0x2);
        vm.prank(address(service));
        WDG.mint(saddress(user1), suint(100 ether));
        vm.prank(user1);

        vm.expectRevert();
        WDG.transfer(saddress(service), suint(20 ether));
    }

    function testPayForService() public {
        address user2 = address(0x3);
        // check if wdg reserve changed
        vm.prank(address(service));
        uint256 initWdgReserve = WDG.trustedBalanceOf(saddress(amm));

        USDC.mint(saddress(user2), suint(20));
        vm.prank(user2);
        USDC.approve(saddress(service), suint(20));

        vm.prank(user2);
        service.payForService(suint(20)); // check balance decreased

        vm.prank(address(service)); //
        uint256 finWdgReserve = WDG.trustedBalanceOf(saddress(amm));

        assertTrue(initWdgReserve > finWdgReserve, "Burn unsuccessful.");

        vm.prank(user2);
        vm.expectRevert(); // not enough balance
        service.payForService(suint(20));
    }

    function testAllocateReward() public {
        vm.prank(oracleAddress);
        // allocating reward to service to bypass whitelisting
        service.allocateReward(saddress(service), suint(20 ether));

        vm.prank(address(service));
        uint256 bal = WDG.balanceOf();

        assertEq(bal, 20 ether, "Minted balances do not match");
    }

    function testAllocateRewardFail() public {
        address user3 = address(0x4);
        vm.prank(user3);
        vm.expectRevert();
        service.allocateReward(saddress(user3), suint(20 ether));
    }

    function testoperatorWithdraw() public {
        address user5 = address(0x6);
        vm.prank(address(service));
        WDG.mint(saddress(user5), suint256(200));

        vm.prank(user5);
        uint256 wdCap = service.viewWithdrawalCap();
        assertEq(wdCap, 100, "Incorrect withdrawal cap.");

        vm.prank(user5);
        service.operatorWithdraw(suint256(100));

        vm.prank(user5);
        uint256 newBalance = USDC.balanceOf();
        assertTrue(newBalance == 100, "Swap balance incorrect");

        vm.prank(user5);
        vm.expectRevert();
        service.viewWithdrawalCap();
    }
}
