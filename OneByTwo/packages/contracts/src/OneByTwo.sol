// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

// contract goals
/* Restaurant Token Contracts
Tokens can be distributed to customers by the restaurant, or (if allowed), traded on the secondary market.
Will only allow transactions between clients and the restaurant address, or all transactions depending on permissions.

Successfully sending a token from a restaurant to a user,
successfully blocking a token send for a user to another user,
successfully sending a token from a user back to the original restaurant.
*/
import { ISRC20 } from "./ISRC20.sol";
import { SRC20 } from "./SRC20.sol";

contract OneByTwo{

    //The number of consumers and restaurants should be publically accessible. 
    uint256 public restaurantCount;
    uint256 constant TOKEN_SUPPLY = 1e24;

    //mapping for searching through users via address, also might be cool to shield the addresses here? Just so I can get a sense
    // of the s-types in practice.
    mapping(address=>address) public restaurantsTokens;

    // how much rev has gone to each restaurant
    mapping(address=>suint256) internal restaurantRevenue;

    //keep track of spend per person
    mapping(address=>mapping(address=>suint256)) internal userSpend;

    event Register(address Restaurant_, address tokenAddress);   // Event of a new address registering as R

    // restaurants listen to this
    event SpentAtRestaurant(address Restaurant_, address Consumer_);

    // Thought here is that people can see when certain restaurants have tokens up for grabs, but
    // can't see who has them right now, or who returned them. Only public user info is whether a given address
    // is registered, but even then 

    constructor() {
    }

    // Function to register new users and then log the event via emit. For both R and C.
    function registerRestaurant(string calldata name_, string calldata symbol_) public {

        if (restaurantsTokens[msg.sender] != address(0)) {
            revert ("restaurant already registered");
        }

        SRC20 token = new SRC20 (name_, symbol_, 18, saddress(msg.sender), suint256(TOKEN_SUPPLY));
        restaurantsTokens[msg.sender] = address(token);

        restaurantCount++;

        emit Register(msg.sender, address(token));
    }

    function spendAtRestaurant(address restaurant_) public payable {

        if (restaurantsTokens[restaurant_] == address(0)) {
            revert ("restaurant is not registered");
        }

        restaurantRevenue[restaurant_] = restaurantRevenue[restaurant_] + suint256(msg.value);
        userSpend[restaurant_][msg.sender] = userSpend[restaurant_][msg.sender] + suint256(msg.value);

        emit SpentAtRestaurant(restaurant_, msg.sender);

    }

    function checkTotalSpendRestaurant() public view returns (uint256){

        if (restaurantsTokens[msg.sender] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(restaurantRevenue[msg.sender]);
    }

    function checkUserSpendRestaurant(address user_) public view returns (uint256){

        if (restaurantsTokens[msg.sender] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(userSpend[msg.sender][user_]);

    }

    function checkSpendUser(address restaurant_) public view returns (uint256){

        if (restaurantsTokens[restaurant_] == address(0)) {
            revert ("restaurant is not registered");
        }

        return uint(userSpend[restaurant_][msg.sender]);

    }

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