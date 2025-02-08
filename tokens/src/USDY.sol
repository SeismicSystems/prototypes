// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.20;

import {SERC20} from "./SERC20.sol";

/**
 * @title USDY - Yield-bearing USD Stablecoin with Privacy Features
 * @notice A yield-bearing stablecoin that uses shielded types for privacy protection
 * @dev Implements SERC20 for shielded balances and transfers. This is a final implementation, not meant to be inherited from.
 */
contract USDY is SERC20 {
    // Base value for rewardMultiplier (18 decimals)
    uint256 private constant BASE = 1e18;
    
    // Current reward multiplier, represents accumulated yield
    suint256 private rewardMultiplier;

    // Shielded shares storage
    mapping(saddress => suint256) private _shares;
    suint256 private _totalShares;

    // Allowances mapping for each token owner => spender => amount
    mapping(saddress => mapping(saddress => suint256)) private _allowances;

    // Access control roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Role management
    mapping(bytes32 => mapping(address => bool)) private _roles;
    
    // Pause state
    bool private _paused;

    // Events
    event RewardMultiplierUpdated(uint256 newMultiplier);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Paused(address account);
    event Unpaused(address account);

    // Custom errors
    error InvalidRewardMultiplier(uint256 multiplier);
    error ZeroRewardIncrement();
    error MissingRole(bytes32 role, address account);
    error TransferWhilePaused();

    /**
     * @notice Constructs the USDY contract
     * @param admin The address that will have admin rights
     */
    constructor(address admin) SERC20("USD Yield", "USDY") {
        if (admin == address(0)) revert ERC20InvalidReceiver(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        rewardMultiplier = suint256(BASE); // Initialize with 1.0 multiplier
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Converts an amount of tokens to shares
     * @param amount The amount of tokens to convert
     * @return The equivalent amount of shares
     */
    function convertToShares(suint256 amount) internal view returns (suint256) {
        if (uint256(rewardMultiplier) == 0) return amount;
        return (amount * suint256(BASE)) / rewardMultiplier;
    }

    /**
     * @notice Converts an amount of shares to tokens
     * @param shares The amount of shares to convert
     * @return The equivalent amount of tokens
     */
    function convertToTokens(suint256 shares) internal view returns (suint256) {
        return (shares * rewardMultiplier) / suint256(BASE);
    }

    /**
     * @notice Returns the total amount of shares
     * @return The total amount of shares
     */
    function totalShares() public view returns (uint256) {
        return uint256(_totalShares);
    }

    /**
     * @notice Returns the total supply of tokens
     * @return The total supply of tokens, accounting for yield
     */
    function totalSupply() public view override returns (uint256) {
        return uint256(convertToTokens(_totalShares));
    }

    /**
     * @notice Returns the current reward multiplier
     * @return The current reward multiplier value
     */
    function getCurrentRewardMultiplier() public view returns (uint256) {
        return uint256(rewardMultiplier);
    }

    /**
     * @notice Returns the amount of shares owned by the account
     * @param account The account to check
     * @return The amount of shares owned by the account, or 0 if caller is not the account owner
     */
    function sharesOf(saddress account) public view returns (uint256) {
        // Only return shares if caller is the account owner
        if (account == saddress(_msgSender())) {
            return uint256(_shares[account]);
        }
        return 0;
    }

    /**
     * @notice Override balanceOf to calculate balance based on shares and current reward multiplier
     * @param account The account to check the balance of
     * @return The current balance in tokens, accounting for yield
     */
    function balanceOf(saddress account) public view override returns (uint256) {
        // Only return balance if caller is the account owner
        if (account == saddress(_msgSender())) {
            return uint256(convertToTokens(_shares[account]));
        }
        return 0;
    }

    /**
     * @notice Modifier that checks if the caller has a specific role
     */
    modifier onlyRole(bytes32 role) {
        address sender = _msgSender();
        if (!hasRole(role, sender)) {
            revert MissingRole(role, sender);
        }
        _;
    }

    /**
     * @notice Modifier to make a function callable only when the contract is not paused
     */
    modifier whenNotPaused() {
        if (_paused) revert TransferWhilePaused();
        _;
    }

    /**
     * @notice Returns true if `account` has been granted `role`
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        if (account == address(0)) return false;
        return _roles[role][account];
    }

    /**
     * @notice Grants `role` to `account`
     * @dev The caller must have the admin role
     */
    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account == address(0)) revert ERC20InvalidReceiver(account);
        _grantRole(role, account);
    }

    /**
     * @notice Revokes `role` from `account`
     * @dev The caller must have the admin role
     */
    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account == address(0)) revert ERC20InvalidSender(account);
        _revokeRole(role, account);
    }

    /**
     * @notice Internal function to grant a role to an account
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @notice Internal function to revoke a role from an account
     */
    function _revokeRole(bytes32 role, address account) internal {
        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @notice Returns true if the contract is paused, and false otherwise
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @notice Updates the reward multiplier to reflect new yield
     * @param increment The amount to increase the multiplier by
     */
    function addRewardMultiplier(uint256 increment) external onlyRole(ORACLE_ROLE) {
        if (increment == 0) revert ZeroRewardIncrement();
        
        uint256 newMultiplierValue = uint256(rewardMultiplier) + increment;
        if (newMultiplierValue < BASE) {
            revert InvalidRewardMultiplier(newMultiplierValue);
        }
        
        rewardMultiplier = suint256(newMultiplierValue);
        emit RewardMultiplierUpdated(newMultiplierValue);
    }

    /**
     * @notice Mints new tokens to a shielded address
     * @param to The shielded address to mint to
     * @param amount The shielded amount to mint
     */
    function mint(saddress to, suint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from a shielded address
     * @param from The shielded address to burn from
     * @param amount The shielded amount to burn
     */
    function burn(saddress from, suint256 amount) external onlyRole(BURNER_ROLE) whenNotPaused {
        _burn(from, amount);
    }

    /**
     * @notice Pauses all token transfers
     */
    function pause() external onlyRole(PAUSE_ROLE) {
        if (_paused) revert TransferWhilePaused();
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @notice Unpauses all token transfers
     */
    function unpause() external onlyRole(PAUSE_ROLE) {
        if (!_paused) revert TransferWhilePaused();
        _paused = false;
        emit Unpaused(_msgSender());
    }

    /**
     * @dev Override _update to handle shielded shares accounting
     * @param from The sender address
     * @param to The recipient address  
     * @param value The amount of tokens to transfer
     */
    function _update(saddress from, saddress to, suint256 value) internal override {
        _beforeTokenTransfer(from, to, value);

        suint256 shares = convertToShares(value);

        if (from == saddress(address(0))) {
            // Minting
            _totalShares += shares;
            _shares[to] += shares;
        } else if (to == saddress(address(0))) {
            // Burning
            suint256 fromShares = _shares[from];
            if (fromShares < shares) {
                revert ERC20InsufficientBalance(address(from), uint256(convertToTokens(fromShares)), uint256(value));
            }
            unchecked {
                _shares[from] = fromShares - shares;
                _totalShares -= shares;
            }
        } else {
            // Transfer
            suint256 fromShares = _shares[from];
            if (fromShares < shares) {
                revert ERC20InsufficientBalance(address(from), uint256(convertToTokens(fromShares)), uint256(value));
            }
            unchecked {
                _shares[from] = fromShares - shares;
                _shares[to] += shares;
            }
        }

        emit Transfer(address(from), address(to), uint256(value));

        _afterTokenTransfer(from, to, value);
    }

    /**
     * @notice Hook that is called before any transfer
     * @dev Adds pausable functionality to transfers
     */
    function _beforeTokenTransfer(saddress from, saddress to, suint256 value) internal override {
        if (_paused) revert TransferWhilePaused();
    }

    /**
     * @notice Hook that is called after any transfer
     */
    function _afterTokenTransfer(saddress from, saddress to, suint256 value) internal override {
        // No additional functionality needed after transfer
    }

    /**
     * @notice Transfers a specified number of tokens from the caller's address to the recipient.
     * @dev Uses _update for share-based accounting while maintaining token-based interface
     * @param to The shielded address to which tokens will be transferred.
     * @param amount The shielded number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(saddress to, suint256 amount) public override whenNotPaused returns (bool) {
        if (to == saddress(address(0))) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(saddress(_msgSender()), to, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from one address to another using the allowance mechanism
     * @dev Uses _update for share-based accounting while maintaining token-based interface
     * @param from The shielded address to transfer from
     * @param to The shielded address to transfer to
     * @param amount The shielded amount to transfer
     * @return A boolean value indicating whether the operation succeeded
     */
    function transferFrom(saddress from, saddress to, suint256 amount) public override whenNotPaused returns (bool) {
        address spender = _msgSender();
        
        if (from == saddress(address(0))) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == saddress(address(0))) {
            revert ERC20InvalidReceiver(address(0));
        }

        suint256 currentAllowance = _allowances[from][saddress(spender)];
        if (currentAllowance != type(suint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(spender, uint256(currentAllowance), uint256(amount));
            }
            unchecked {
                _allowances[from][saddress(spender)] = currentAllowance - amount;
            }
        }

        _update(from, to, amount);
        return true;
    }

    /**
     * @notice This is the exact same implementation as the one in SERC20.sol
     * @dev See {SIERC20-allowance}.
     * Returns actual allowance if caller is either the owner or the spender,
     * returns 0 otherwise to maintain privacy.
     */
    function allowance(saddress owner, saddress spender) public view override returns (uint256) {
        saddress caller = saddress(_msgSender());
        if (caller == owner || caller == spender) {
            return uint256(_allowances[saddress(owner)][saddress(spender)]);
        }
        return 0;
    }

    /**
     * @notice Sets `amount` as the allowance of `spender` over the caller's tokens
     * @param spender The address which will spend the funds
     * @param amount The amount of tokens to be spent
     * @return A boolean value indicating whether the operation succeeded
     */
    function approve(saddress spender, suint256 amount) public override whenNotPaused returns (bool) {
        address owner = _msgSender();
        if (spender == saddress(address(0))) {
            revert ERC20InvalidSpender(address(0));
        }
        if (saddress(owner) == saddress(address(0))) {
            revert ERC20InvalidSpender(address(0));
        }

        _allowances[saddress(owner)][spender] = amount;
        emit Approval(owner, address(spender), uint256(amount));

        return true;
    }

    /**
     * @notice Atomically increases the allowance granted to `spender` by the caller
     * @param spender The address which will spend the funds
     * @param addedValue The amount of tokens to increase the allowance by
     * @return A boolean value indicating whether the operation succeeded
     */
    function increaseAllowance(saddress spender, suint256 addedValue) public virtual override whenNotPaused returns (bool) {
        address owner = _msgSender();
        if (spender == saddress(address(0))) {
            revert ERC20InvalidSpender(address(0));
        }

        unchecked {
            _allowances[saddress(owner)][spender] += addedValue;
        }
        emit Approval(owner, address(spender), uint256(_allowances[saddress(owner)][spender]));

        return true;
    }

    /**
     * @notice Atomically decreases the allowance granted to `spender` by the caller
     * @param spender The address which will spend the funds
     * @param subtractedValue The amount of tokens to decrease the allowance by
     * @return A boolean value indicating whether the operation succeeded
     */
    function decreaseAllowance(saddress spender, suint256 subtractedValue) public virtual override whenNotPaused returns (bool) {
        address owner = _msgSender();
        if (spender == saddress(address(0))) {
            revert ERC20InvalidSpender(address(0));
        }

        suint256 currentAllowance = _allowances[saddress(owner)][spender];
        if (currentAllowance < subtractedValue) {
            revert ERC20InsufficientAllowance(address(spender), uint256(currentAllowance), uint256(subtractedValue));
        }
        unchecked {
            _allowances[saddress(owner)][spender] = currentAllowance - subtractedValue;
        }
        emit Approval(owner, address(spender), uint256(_allowances[saddress(owner)][spender]));

        return true;
    }
}
