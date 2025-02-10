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

    // starting token balance distributed to the restaurant owners
    uint256 constant SHARE_PERCENTAGE = 10; //The percent of revenue willing to be distributed.


    mapping(address=>address) public restaurantsTokens; // mapping(restaurant (owner) address => restaurant's SRC20 token)
    mapping(address=>suint256) internal restaurantTotalRevenue; // mapping(restauraunt address => total revenue)
    mapping(address=>mapping(address=>suint256)) internal customerSpend; // mapping(restaurant address => mapping(customer address => spend amount))

    event Register(address Restaurant_, address tokenAddress);   // Event of a new address registering as a restaurant
    event SpentAtRestaurant(address Restaurant_, address Consumer_); //Event of a user spending at a restaurant

    constructor() {
    }

    // modifier to check that the caller is a registered restaurant
    modifier reqIsRestaurant(address _restaurantAddress) {
        if (restaurantsTokens[_restaurantAddress] == address(0)) {
            revert ("restaurant is not registered");
        }
        _;
    }

    // Function to register new restaurants. Handles token minting and delegation, keeps 
    // restaurant count up to date, and then emits the relevant event.
    function registerRestaurant(string calldata name_, string calldata symbol_) public {

        //This is a sample - token distribution should ideally be automated around user spend
        //events to give larger portions of the tokens to early/regular spenders, while maintaining
        //a token pool for the restaurant. Currently, the restaurant has to manually handle distribution.

        if (restaurantsTokens[msg.sender] != address(0)) {
            revert ("restaurant already registered");
        }

        SRC20 token = new SRC20 (name_, symbol_, 18, saddress(msg.sender), suint(1e24));
        restaurantsTokens[msg.sender] = address(token);

        restaurantCount++;

        emit Register(msg.sender, address(token));
    }

    // Function to recieve payment from customers at restaurants and track spending.
    // Updates restaurant total revenue and user spendmetrics. Emits the relevant event.
    // Intended to be called by a customer EOA in return for food.
    function spendAtRestaurant(address restaurant_) public payable reqIsRestaurant(restaurant_) {

        restaurantTotalRevenue[restaurant_] = restaurantTotalRevenue[restaurant_] + suint256(msg.value);
        customerSpend[restaurant_][msg.sender] = customerSpend[restaurant_][msg.sender] + suint256(msg.value);

        /// 
        /// Insert other restaurant business logic here
        /// e.g. distribute nft for special orders, etc
        ///

        emit SpentAtRestaurant(restaurant_, msg.sender);

    }

    // View function to check the total spend at a given restaurant.
    // reverts if caller is not a registered restaurant address.
    function checkTotalSpendRestaurant() public view reqIsRestaurant(msg.sender) returns (uint256){
        return uint(restaurantTotalRevenue[msg.sender]);
    }

    //View function for a restaurant to check a specific users spend.
    // reverts if caller is not a registered restaurant address.
    function checkCustomerSpendRestaurant(address user_) public view reqIsRestaurant(msg.sender) returns (uint256){
        return uint(customerSpend[msg.sender][user_]);
    }

    //View function for a user to check their spend at a given restaurant. 
    // reverts if caller is not a registered restaurant address.
    // Note that the resturant can only check their own data
    function checkSpendCustomer(address restaurant_) public view reqIsRestaurant(restaurant_) returns (uint256){
        return uint(customerSpend[restaurant_][msg.sender]);

    }

    // checkOut() allows a user to trade in their tokens for a given restaurant
    // for their respective portion of the revenue pool.
    function checkOut(address restaurant_, suint256 amount) public reqIsRestaurant(restaurant_) {

        address tokenAddress = restaurantsTokens[restaurant_]; // get the address of the restaurant's token
        ISRC20 token = ISRC20(tokenAddress);

        // decrease msg.sender's allowance by amount so they cannot double checkOut
        // note: reverts if amount is more than the user's allowance
        token.transferFrom(saddress(msg.sender), saddress(restaurant_), amount); 

        // calculate the entitlement
        // entitledShare = amount / suint(token.totalSupply());
        // shareableRevenue = suint256(totalRev / suint(SHARE_PERCENTAGE));
        // entitlement = entitledShare * shareableRevenue;
        // reordering operations, we get:
        suint256 totalRev = restaurantTotalRevenue[restaurant_];
        uint256 entitlement = uint256(amount * totalRev) / token.totalSupply();

        // send the entitlement to the customer
        bool success = payable(msg.sender).send(uint(entitlement));
        if (!success) {
            revert("Payment Failed");
        }
    }

}