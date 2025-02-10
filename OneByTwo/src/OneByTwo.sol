// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

// contract goals
/* Restaurant Token Contracts
Tokens can be distributed to customers by the restaurant, and can be sent back to said restaurants.
No other transactions will be allowed.
*/

import { ISRC20 } from "./ISRC20.sol";
import { SRC20 } from "./SRC20.sol";

contract OneByTwo{

    //The number of consumers and restaurants should be publically accessible. 
    uint256 public restaurantCount;
    uint256 constant TOKEN_SUPPLY = 1e24;

    //This mapping gets the token address of each restaurants token given the address of the
    // restaurant user.
    mapping(address=>address) public restaurantsTokens;

    //This mapping gets the total revenue a restaurant has recieved given the address of the
    // restaurant user. The revenue is stored as a suint to shield it from observers.
    mapping(address=>suint256) internal restaurantRevenue;

    //This mapping keeps track of the spend contributed by individual users. It does this
    //by mapping the restaurant address to another mapping of all user addresses and their
    //relevant spend amounts at the given restaurant. The value is shielded from observers.
    mapping(address=>mapping(address=>suint256)) internal userSpend;

    event Register(address Restaurant_, address tokenAddress);   // Event of a new address registering as a restaurant
    event SpentAtRestaurant(address Restaurant_, address Consumer_); //Event of a user spending at a restaurant

    constructor() {
    }

    // Function to register new restaurants. Handles token minting and delegation, keeps 
    // restaurant count up to date, and then emits the relevant event.
    function registerRestaurant(string calldata name_, string calldata symbol_) public {

        if (restaurantsTokens[msg.sender] != address(0)) {
            revert ("restaurant already registered");
        }

        SRC20 token = new SRC20 (name_, symbol_, 18, saddress(msg.sender), suint256(TOKEN_SUPPLY));
        restaurantsTokens[msg.sender] = address(token);

        restaurantCount++;

        emit Register(msg.sender, address(token));
    }

    // Function to track spending by users at restaurants. Updates restaurant total revenue and user spend
    // metrics. Emits the relevant event.
    function spendAtRestaurant(address restaurant_) public payable {

        if (restaurantsTokens[restaurant_] == address(0)) {
            revert ("restaurant is not registered");
        }

        restaurantRevenue[restaurant_] = restaurantRevenue[restaurant_] + suint256(msg.value);
        userSpend[restaurant_][msg.sender] = userSpend[restaurant_][msg.sender] + suint256(msg.value);

        emit SpentAtRestaurant(restaurant_, msg.sender);

    }

    //View function to check the total spend at a given restaurant.
    function checkTotalSpendRestaurant() public view returns (uint256){

        if (restaurantsTokens[msg.sender] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(restaurantRevenue[msg.sender]);
    }

    //View function for a restaurant to check a specific users spend. Not restaurants
    //can only check the spend of the user at their address - not for any other restaurant.
    function checkUserSpendRestaurant(address user_) public view returns (uint256){

        if (restaurantsTokens[msg.sender] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(userSpend[msg.sender][user_]);

    }

    //View function for a user to check their spend at a given restaurant. Note that
    //the can only place themselves as a user - not any abstract address.
    function checkSpendUser(address restaurant_) public view returns (uint256){

        if (restaurantsTokens[restaurant_] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(userSpend[restaurant_][msg.sender]);

    }

    //checkOut() allows a user to trade in their tokens for a given restaurant
    // for their respective portion of the revenue pool.
    function checkOut(address restaurant_, suint256 amount) public {

        address tokenAddress = restaurantsTokens[restaurant_];

        if (tokenAddress == address(0)) {
            revert ("restaurant is not registered");
        }

        ISRC20 token = ISRC20(tokenAddress);
        token.transferFrom(saddress(msg.sender), saddress(restaurant_), amount);

        suint256 totalRev = restaurantRevenue[restaurant_];
        uint256 entitlement = uint256(amount * totalRev) / token.totalSupply();

        bool success = payable(msg.sender).send(entitlement);

        if (!success) {
            revert("Payment Failed");
        }


    }

}