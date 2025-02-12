// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import "../src/Riff.sol";
import {Test, console} from "forge-std/Test.sol";

/*//////////////////////////////////////////////////////////////
//                    ViolinAMMTest Contract
//////////////////////////////////////////////////////////////*/
contract ViolinAMMTest is Test {
    /*//////////////////////////////////////////////////////////////
    //                        AMM STORAGE
    //////////////////////////////////////////////////////////////*/
    Riff public amm;

    /*//////////////////////////////////////////////////////////////
    //                        TOKEN STORAGE
    //////////////////////////////////////////////////////////////*/
    ViolinCoin baseAsset;
    ViolinCoin quoteAsset;

    /*//////////////////////////////////////////////////////////////
    //                        AMM STORAGE
    //////////////////////////////////////////////////////////////*/
    address testAdmin = address(0xabcd);

    address constant violinAddress = address(0x123);

    uint256 constant WAD = 1e18;
    uint8 constant WAD_ZEROS = 18;

    address constant SWAPPER1_ADDR = address(123);
    address constant SWAPPER2_ADDR = address(456);

    address constant NON_LISTENER_ADDR = address(789);

    /*//////////////////////////////////////////////////////////////
    //                        SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        baseAsset = new ViolinCoin(address(this), "Circle", "USDC", 18);
        quoteAsset = new ViolinCoin(address(this), "Chainlink", "LINK", 18);

        // Start with pool price 1 LINK = 20 USDC
        amm = new Riff(ViolinCoin(address(baseAsset)), ViolinCoin(address(quoteAsset)), WAD, testAdmin, violinAddress);
        baseAsset.mint(saddress(address(this)), suint256(200000 * WAD));
        quoteAsset.mint(saddress(address(this)), suint256(10000 * WAD));
        baseAsset.approve(saddress(address(amm)), suint256(200000 * WAD));
        quoteAsset.approve(saddress(address(amm)), suint256(10000 * WAD));
        amm.addLiquidity(suint256(200000 * WAD), suint256(10000 * WAD));

        // Two swappers start with 50k units of each, LINK and USDC
        baseAsset.mint(saddress(SWAPPER1_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(SWAPPER1_ADDR), suint256(50000 * WAD));
        baseAsset.mint(saddress(SWAPPER2_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(SWAPPER2_ADDR), suint256(50000 * WAD));

        // Another address that starts with 50k units of each, LINK and USDC
        baseAsset.mint(saddress(NON_LISTENER_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(NON_LISTENER_ADDR), suint256(50000 * WAD));
    }

    /*//////////////////////////////////////////////////////////////
    //                        TEST CASES 
    //////////////////////////////////////////////////////////////*/

    /*
     * Test case for zero swap. If the user attempts to swap zero of both assets,
     * then there is no change in the price.
     */
    function test_ZeroSwap() public {
        // Fetch the initial price as violin
        vm.startPrank(violinAddress);
        uint256 priceT0 = amm.getPrice();
        vm.stopPrank();

        // Now try a zero swap of base
        vm.startPrank(SWAPPER1_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(0), suint256(0));
        vm.stopPrank();

        // Another user attempts a zero swap of quote
        vm.startPrank(SWAPPER2_ADDR);
        quoteAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(0), suint256(0));
        vm.stopPrank();

        // Finally access the price as the violin
        vm.startPrank(violinAddress);
        assertEq(priceT0, amm.getPrice());
        vm.stopPrank();
    }

    /*
     * Test case for price going up after swap
     */
    function test_PriceUp() public {
        vm.startPrank(violinAddress);
        uint256 priceT0 = amm.getPrice();
        vm.stopPrank();

        vm.startPrank(SWAPPER1_ADDR);
        uint256 swapperBaseT0 = baseAsset.balanceOf();
        uint256 swapperQuoteT0 = quoteAsset.balanceOf();

        baseAsset.approve(saddress(address(amm)), suint256(30000 * WAD));
        amm.swap(suint256(30000 * WAD), suint256(0));

        uint256 swapperBaseT1 = baseAsset.balanceOf();
        uint256 swapperQuoteT1 = quoteAsset.balanceOf();
        vm.stopPrank();

        vm.startPrank(violinAddress);
        assertLt(priceT0, amm.getPrice());
        vm.stopPrank();

        assertGt(swapperBaseT0, swapperBaseT1);
        assertLt(swapperQuoteT0, swapperQuoteT1);
    }

    /*
     * Test case for price going down after swap. 
     */
    function test_PriceNetDown() public {
        vm.startPrank(violinAddress);
        uint256 priceT0 = amm.getPrice();
        vm.stopPrank();

        vm.startPrank(SWAPPER1_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.swap(suint256(5000 * WAD), suint256(0));
        vm.stopPrank();

        vm.startPrank(SWAPPER2_ADDR);
        quoteAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.swap(suint256(0), suint256(5000 * WAD));
        vm.stopPrank();

        vm.startPrank(violinAddress);
        assertGt(priceT0, amm.getPrice());
        vm.stopPrank();
    }

    /*
     * Test case for access control. Only the violin can call getPrice.
     */
    function test_AccessControl() public {
        vm.startPrank(SWAPPER1_ADDR);
        vm.expectRevert("You don't have violin access");
        amm.getPrice();
        vm.stopPrank();

        vm.startPrank(violinAddress);
        amm.getPrice();
        vm.stopPrank();
    }

    /*
     * Test case for swap access control. Any user can call swap
     */
    function test_SwapAccessControl() public {
        vm.startPrank(SWAPPER1_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.swap(suint256(5000 * WAD), suint256(0));
        vm.stopPrank();

        vm.startPrank(SWAPPER2_ADDR);
        quoteAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.swap(suint256(0), suint256(5000 * WAD));
        vm.stopPrank();
    }

    /*
     * Test case for liquidity invariance. If two different listeners perform
     * swaps, the price should remain almost the same with some level of rounding
     * error.
     */
    function test_LiquidityInvariance() public {
        vm.startPrank(address(this));
        uint256 baseBefore = baseAsset.balanceOf();
        uint256 quoteBefore = quoteAsset.balanceOf();

        uint256 invariantBefore = baseBefore * quoteBefore;
        vm.stopPrank();

        // Have two different listeners perform swaps
        vm.startPrank(SWAPPER1_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(500 * WAD), suint256(0));
        vm.stopPrank();

        uint256 baseAfterSwp1 = baseAsset.balanceOf();
        uint256 quoteAfterSwp1 = quoteAsset.balanceOf();

        uint256 invariantAfterSwp1 = baseAfterSwp1 * quoteAfterSwp1;

        vm.startPrank(SWAPPER2_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(20000 * WAD));
        amm.swap(suint256(200 * WAD), suint256(0));
        vm.stopPrank();

        vm.startPrank(address(this));
        uint256 baseAfterSwp2 = baseAsset.balanceOf();
        uint256 quoteAfterSwp2 = quoteAsset.balanceOf();
        uint256 invariantAfterSwp2 = baseAfterSwp2 * quoteAfterSwp2;
        vm.stopPrank();

        // Allow a small tolerance for rounding error.
        assertApproxEqRel(invariantBefore, invariantAfterSwp1, 1e16);
        assertApproxEqRel(invariantBefore, invariantAfterSwp2, 1e16);
        vm.stopPrank();
    }
}
