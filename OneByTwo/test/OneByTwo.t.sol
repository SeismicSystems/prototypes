// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {OneByTwo} from "../src/OneByTwo.sol";
import {ISRC20} from "../src/ISRC20.sol";

contract OneByTwoTest is Test {
    OneByTwo public onebytwo;

    // Declare event types for use in event emission tests.
    event Register(address Restaurant_, address tokenAddress);
    event SpentAtRestaurant(address Restaurant_, address Consumer_);

    function setUp() public {
        onebytwo = new OneByTwo();
    }

    /// @notice Ensure that the restaurant count increases upon registration.
    function test_oneNewRestaurant() public {
        uint256 start = onebytwo.restaurantCount();
        assertEq(start, 0);
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        uint256 finish = onebytwo.restaurantCount();
        assertEq(finish, 1);
    }

    /// @notice A restaurant should not be able to register twice.
    function test_registerRestaurantTwice() public {
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        vm.expectRevert("restaurant already registered");
        onebytwo.registerRestaurant("Restaurant One", "RONE");
    }

    /// @notice After registration, the restaurant’s token address should be set.
    function test_restaurantTokenMapping() public {
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        address tokenAddress = onebytwo.restaurantsTokens(address(this));
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
    }

    /// @notice Spending at an unregistered restaurant should revert.
    function test_spendAtRestaurantRevertsForNonRegisteredRestaurant() public {
        address unregisteredRestaurant = address(0x123);
        vm.expectRevert("restaurant is not registered");
        onebytwo.spendAtRestaurant(unregisteredRestaurant);
    }

    /// @notice Spending at a registered restaurant updates revenue and user spend correctly.
    function test_spendAtRestaurantUpdatesRevenue() public {
        // Use a different address for the restaurant.
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        // Simulate a consumer spending 1 ether at the restaurant.
        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);
        uint256 spendAmount = 1 ether;
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spendAmount}(restaurant);

        // Check the restaurant’s total revenue (only a registered restaurant can call this).
        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, spendAmount);

        // Check that the restaurant can view this consumer’s spend.
        vm.prank(restaurant);
        uint256 userSpendAmount = onebytwo.checkUserSpendRestaurant(consumer);
        assertEq(userSpendAmount, spendAmount);

        // Check that the consumer can view his/her spend at the restaurant.
        vm.prank(consumer);
        uint256 spendUser = onebytwo.checkSpendUser(restaurant);
        assertEq(spendUser, spendAmount);
    }

    /// @notice Multiple spends from the same consumer should accumulate.
    function test_multipleSpendsAccumulate() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 4 ether);
        uint256 spend1 = 1 ether;
        uint256 spend2 = 2 ether;
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, spend1 + spend2);

        vm.prank(restaurant);
        uint256 userSpendAmount = onebytwo.checkUserSpendRestaurant(consumer);
        assertEq(userSpendAmount, spend1 + spend2);

        vm.prank(consumer);
        uint256 spendUser = onebytwo.checkSpendUser(restaurant);
        assertEq(spendUser, spend1 + spend2);
    }

    /// @notice Multiple spends from the different consumers should accumulate.
    function test_multipleDifSpendsAccumulate() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        address consumer2 = address(0x2345);
        vm.deal(consumer, 4 ether);
        vm.deal(consumer2, 4 ether);

        uint256 spend1 = 1 ether;
        uint256 spend2 = 2 ether;

        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(consumer2);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer2);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, 2 * (spend1 + spend2));

        vm.prank(restaurant);
        uint256 userSpendAmount = onebytwo.checkUserSpendRestaurant(consumer);
        assertEq(userSpendAmount, spend1 + spend2);
    
        vm.prank(restaurant);
        uint256 userSpendAmount2 = onebytwo.checkUserSpendRestaurant(consumer2);
        assertEq(userSpendAmount2, spend1 + spend2);

        vm.prank(consumer);
        uint256 spendUser = onebytwo.checkSpendUser(restaurant);
        assertEq(spendUser, spend1 + spend2);

        vm.prank(consumer2);
        uint256 spendUser2 = onebytwo.checkSpendUser(restaurant);
        assertEq(spendUser2, spend1 + spend2);
    }

    /// @notice Only a registered restaurant can call checkTotalSpendRestaurant.
    function test_checkTotalSpendRestaurantNonRegistered() public {
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkTotalSpendRestaurant();
    }

    /// @notice Only a registered restaurant can call checkUserSpendRestaurant.
    function test_checkUserSpendRestaurantNonRegistered() public {
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkUserSpendRestaurant(address(0x234));
    }

    /// @notice A consumer calling checkSpendUser for an unregistered restaurant should revert.
    function test_checkSpendUserNonRegisteredRestaurant() public {
        address unregisteredRestaurant = address(0x123);
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkSpendUser(unregisteredRestaurant);
    }

    /// @notice Test that the SpentAtRestaurant event is emitted with the correct parameters.
    function test_spentAtRestaurantEmitsEvent() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);
        uint256 spendAmount = 1 ether;

        // Expect the SpentAtRestaurant event with the given restaurant and consumer.
        vm.expectEmit(true, true, false, false);
        emit SpentAtRestaurant(restaurant, consumer);

        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spendAmount}(restaurant);
    }

    /// @notice Test that the Register event is emitted when a restaurant registers.
    function test_registerRestaurantEmitsEvent() public {
        // Record logs so that we can inspect emitted events.
        vm.recordLogs();
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        // Compute the expected signature of the Register event.
        bytes32 expectedSig = keccak256("Register(address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == expectedSig) {
                // Decode the event data.
                (address restaurant, address token) = abi.decode(entries[i].data, (address, address));
                assertEq(restaurant, address(this));
                assertTrue(token != address(0), "Token address in event should not be zero");
                found = true;
                break;
            }
        }
        assertTrue(found, "Register event not found");
    }

    function test_sendTokens() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(restaurant);
        token.transfer(saddress(consumer), suint256(1000));

        vm.prank(consumer);
        uint256 balance = token.balanceOf();
        assertEq(balance, 1000);
    }

    function test_sendTokensIllegal() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        address consumer2 = address(0x456);
        vm.deal(consumer, 2 ether);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(restaurant);
        token.transfer(saddress(consumer), suint256(1000));

        vm.prank(consumer);
        uint256 balance = token.balanceOf();
        assertEq(balance, 1000);

        vm.prank(consumer);
        vm.expectRevert();
        token.transfer(saddress(consumer2), suint256(1000));
    }

    function test_checkOut() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address buyer = address(0x234);
        address holder = address(0x456);

        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        onebytwo.spendAtRestaurant{value: 1 ether}(restaurant);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(restaurant);
        token.transfer(saddress(holder), suint256(1e9));

        vm.prank(holder);
        uint256 balance = token.balanceOf();
        assertEq(balance, 1e9);

        vm.prank(holder);
        onebytwo.checkOut(restaurant, suint256(5e8));

        assertEq(holder.balance, 500);
    }

    function test_checkOutNoTokens() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address buyer = address(0x234);
        address holder = address(0x456);

        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        onebytwo.spendAtRestaurant{value: 1 ether}(restaurant);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(holder);
        uint256 balance = token.balanceOf();
        assertEq(balance, 0);

        vm.prank(holder);
        vm.expectRevert();
        onebytwo.checkOut(restaurant, suint256(5e8));
    }
}
