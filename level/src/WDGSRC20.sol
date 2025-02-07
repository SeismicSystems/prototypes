// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ISRC20} from "./SRC20.sol";

/*//////////////////////////////////////////////////////////////
//                         WDGSRC20 Contract
//////////////////////////////////////////////////////////////*/

/// @title WDGSRC20 - Privacy-Preserving Restricted Transfer Token
/// @notice An ERC20-like token implementation that uses shielded data types and restricts transfers
/// @dev Implements transfer restrictions and uses `saddress` and `suint256` types for privacy
/// @dev Transfers are only allowed by trusted contracts or after a time-based unlock
abstract contract WDGSRC20 is ISRC20 {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    // All storage variables that will be mutated must be confidential to
    // preserve functional privacy.
    suint256 internal totalSupply;
    mapping(saddress => suint256) internal balance;
    mapping(saddress => mapping(saddress => suint256)) internal allowance;

    /// @notice Duration in blocks before public transfers are enabled
    /// @dev After this block height, transfers become permissionless
    suint256 transferUnlockTime;
    uint256 public constant BLOCKS_PER_EPOCH = 7200; // about a day

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                               SRC20 LOGIC
                        Includes Transfer Restrictions
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the caller's token balance
    /// @dev Only callable by whitelisted addresses or after unlock time
    /// @return Current balance of the caller
    function balanceOf() public view virtual whitelisted returns (uint256) {
        return uint256(balance[saddress(msg.sender)]);
    }

    function trustedBalanceOf(saddress account) public view virtual returns (uint256) {
        require(isTrusted(), "Only trusted addresses can call this function");
        return uint256(balance[account]);
    }

    /// @notice Approves another address to spend tokens
    /// @param spender Address to approve
    /// @param amount Amount of tokens to approve
    /// @return success Always returns true
    function approve(saddress spender, suint256 amount) public virtual returns (bool) {
        allowance[saddress(msg.sender)][spender] = amount;
        return true;
    }

    /// @notice Transfers tokens to another address
    /// @dev Only callable by whitelisted addresses or after unlock time
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return success Always returns true
    function transfer(saddress to, suint256 amount) public virtual whitelisted returns (bool) {
        // msg.sender is public information, casting to saddress below doesn't change this
        balance[saddress(msg.sender)] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }

    /// @notice Transfers tokens on behalf of another address
    /// @dev Only callable by whitelisted addresses or after unlock time
    /// @dev Trusted contracts can transfer unlimited amounts without approval
    /// @param from Source address
    /// @param to Destination address
    /// @param amount Amount to transfer
    /// @return success Always returns true
    function transferFrom(saddress from, saddress to, suint256 amount) public virtual whitelisted returns (bool) {
        suint256 allowed = allowance[from][saddress(msg.sender)]; // Saves gas for limited approvals.
        if (isTrusted()) {
            allowed = suint256(type(uint256).max);
        }

        if (allowed != suint256(type(uint256).max)) {
            allowance[from][saddress(msg.sender)] = allowed - amount;
        }

        balance[from] -= amount;
        unchecked {
            balance[to] += amount;
        }
        return true;
    }

    /// @notice Creates new tokens
    /// @dev Only callable by trusted contracts
    /// @param to Recipient of the minted tokens
    /// @param amount Amount to mint
    function mint(saddress to, suint256 amount) public virtual {
        require(isTrusted());
        totalSupply += amount;
        unchecked {
            balance[to] += amount;
        }
    }

    /// @notice Destroys tokens
    /// @dev Only callable by trusted contracts
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burn(saddress from, suint256 amount) public virtual {
        require(isTrusted(), "Not authorized to burn");
        require(suint256(balanceOf()) >= amount, "Insufficient balance to burn");
        totalSupply -= amount;
        balance[from] -= amount;
    }

    /*//////////////////////////////////////////////////////////////
                        Trusted Address Logic
    //////////////////////////////////////////////////////////////*/

    address public trustedDePinServiceAddress;
    address public trustedAMMAddress;

    function getTrustedDepinServiceAddress() public view returns (address) {
        return trustedDePinServiceAddress;
    }

    /// @notice Sets the DePIN service contract address
    /// @dev Can only be set once
    /// @param _trustedDePinService Address of the DePIN service contract
    function setTrustedDePinServiceAddress(address _trustedDePinService) external {
        require(trustedDePinServiceAddress == address(0), "Address already set");
        trustedDePinServiceAddress = _trustedDePinService;
    }

    function setTrustedAMMAddress(address _trustedAMMAddress) external {
        require(trustedAMMAddress == address(0), "AMM address already set");
        trustedAMMAddress = _trustedAMMAddress;
    }

    /// @notice Checks if caller is a trusted contract
    /// @return True if caller is either the DePIN service or AMM contract
    function isTrusted() public view returns (bool) {
        return msg.sender == trustedDePinServiceAddress || msg.sender == trustedAMMAddress;
    }

    function setTransferUnlockTime(suint256 _transferUnlockTime) external {
        require(msg.sender == trustedDePinServiceAddress, "Not authorized to set unlock time");
        transferUnlockTime = _transferUnlockTime;
    }

    /// @notice Restricts function access to trusted contracts or after unlock time
    /// @dev Used as a modifier for transfer-related functions, all addresses are whitelisted after unlock period
    modifier whitelisted() {
        require(
            isTrusted() || suint256(block.number) % suint256(BLOCKS_PER_EPOCH) > transferUnlockTime,
            "Only trusted addresses can call this function"
        );
        _;
    }

    //////////////////////////////////////////////////////////////*/
}
