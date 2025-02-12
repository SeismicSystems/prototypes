// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

/**
 * @title Restaurant Revenue Sharing and Token System
 * @dev This contract allows restaurants to register, mint tokens, track customer spending,
 * and facilitate revenue sharing through token redemption.
 */
import {Rewards20} from "./Rewards20.sol";


/* The current rewards distribution for customers: token rewards are calculated across ETH spend and pre-existing holdings.
Specifically, through the Rewards20 mint function, when rewards are minted user recieve a boost based on their existing balance
This rewards customers for spending early and often, as repeated spends will grow
faster than infrequent, larger spends. It also encourages holding of tokens rather than immediately cashing out.
*/

contract Nibble {
    /// @notice The total number of registered restaurants.
    uint256 public restaurantCount;

    /// @notice Maps a restaurant (owner) address to its respective Rewards20 token contract address.
    // mapping(restaurant (owner) address => restaurant's Rewards20 token)
    mapping(address => address) public restaurantsTokens;

    /// @dev Maps a restaurant address to its total accumulated revenue.
    // mapping(restauraunt address => total revenue)
    mapping(address => suint256) internal restaurantTotalRevenue;

    /// @dev Tracks how much each customer has spent at a specific restaurant.
    // mapping(restaurant address => mapping(customer address => spend amount))
    mapping(address => mapping(address => suint256)) internal customerSpend;

    /// @notice Emitted when a new restaurant registers and its token is created.
    /// @param Restaurant_ The address of the restaurant owner.
    /// @param tokenAddress The address of the newly created Rewards20 token contract.
    event Register(address Restaurant_, address tokenAddress);

    /// @notice Emitted when a consumer spends at a restaurant.
    /// @param Restaurant_ The address of the restaurant where the transaction occurred.
    /// @param Consumer_ The address of the consumer who spent money.
    event SpentAtRestaurant(address Restaurant_, address Consumer_); //Event of a user spending at a restaurant

    /// @dev Ensures the caller is a registered restaurant.
    /// @param _restaurantAddress The address to check.
    modifier reqIsRestaurant(address _restaurantAddress) {
        if (restaurantsTokens[_restaurantAddress] == address(0)) {
            revert("restaurant is not registered");
        }
        _;
    }

    constructor() {}

    /**
     * @notice Registers a new restaurant and mints an associated token.
     * @dev Assigns a unique Rewards20 token to the restaurant and updates the count.
     * @param name_ The name of the restaurant token.
     * @param symbol_ The symbol of the restaurant token.
     */
    function registerRestaurant(string calldata name_, string calldata symbol_) public {
        //This is a sample - token distribution should ideally be automated around user spend
        //events to give larger portions of the tokens to early/regular spenders, while maintaining
        //a token pool for the restaurant. Currently, the restaurant has to manually handle distribution.

        if (restaurantsTokens[msg.sender] != address(0)) {
            revert("restaurant already registered");
        }

        Rewards20 token = new Rewards20(name_, symbol_, 18, saddress(msg.sender), suint(1e24));
        restaurantsTokens[msg.sender] = address(token);

        restaurantCount++;

        emit Register(msg.sender, address(token));
    }

    /**
     * @notice Allows a customer to make a payment at a restaurant.
     * @dev Updates revenue tracking and mints corresponding tokens to the consumer.
     * @param restaurant_ The address of the restaurant where payment is made.
     */
    function spendAtRestaurant(address restaurant_) public payable reqIsRestaurant(restaurant_) {
        restaurantTotalRevenue[restaurant_] = restaurantTotalRevenue[restaurant_] + suint256(msg.value);
        customerSpend[restaurant_][msg.sender] = customerSpend[restaurant_][msg.sender] + suint256(msg.value);

        // Calculate the number of tokens to mint.
        // Here we assume a 1:1 ratio between wei paid and tokens minted.
        // You can adjust the conversion factor as needed.
        uint256 tokenAmount = msg.value;

        // Mint tokens directly to msg.sender.
        // We assume that restaurantTokens[restaurant_] returns the Rewards20 token contract
        // associated with this restaurant.

        Rewards20 token = Rewards20(restaurantsTokens[restaurant_]);
        token.mint(saddress(msg.sender), suint256(tokenAmount));

        emit SpentAtRestaurant(restaurant_, msg.sender);
    }

    /**
     * @notice Retrieves the total revenue accumulated by the restaurant.
     * @dev Only callable by the restaurant itself.
     * @return The total revenue in suint256.
     */
    function checkTotalSpendRestaurant() public view reqIsRestaurant(msg.sender) returns (uint256) {
        return uint256(restaurantTotalRevenue[msg.sender]);
    }

    /**
     * @notice Retrieves the total spending of a specific customer at the caller's restaurant.
     * @dev Only callable by the restaurant.
     * @param user_ The address of the customer.
     * @return The amount spent in suint256.
     */
    function checkCustomerSpendRestaurant(address user_) public view reqIsRestaurant(msg.sender) returns (uint256) {
        return uint256(customerSpend[msg.sender][user_]);
    }

    /**
     * @notice Retrieves the caller's total spend at a specific restaurant.
     * @dev Only callable by a customer for a restaurant where they have spent.
     * @param restaurant_ The address of the restaurant.
     * @return The amount spent in suint256.
     */
    function checkSpendCustomer(address restaurant_) public view reqIsRestaurant(restaurant_) returns (uint256) {
        return uint256(customerSpend[restaurant_][msg.sender]);
    }

    /**
     * @notice Allows a user to exchange restaurant tokens for a portion of the restaurant's revenue.
     * @dev Transfers tokens back to the restaurant and distributes a proportional revenue share.
     * @param restaurant_ The address of the restaurant where tokens are redeemed.
     * @param amount The amount of tokens to redeem, in suint256.
     */
    function checkOut(address restaurant_, suint256 amount) public reqIsRestaurant(restaurant_) {
        address tokenAddress = restaurantsTokens[restaurant_]; // get the address of the restaurant's token
        Rewards20 token = Rewards20(tokenAddress);

        // decrease msg.sender's allowance by amount so they cannot double checkOut
        // note: reverts if amount is more than the user's allowance
        token.transferFrom(saddress(msg.sender), saddress(restaurant_), amount);

        // calculate the entitlement
        suint256 totalRev = restaurantTotalRevenue[restaurant_];
        uint256 entitlement = uint256(amount * totalRev) / token.totalSupply();

        // send the entitlement to the customer
        bool success = payable(msg.sender).send(uint256(entitlement));
        if (!success) {
            revert("Payment Failed");
        }
    }
}
