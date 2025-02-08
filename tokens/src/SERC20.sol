// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.20;

import {SIERC20} from "./SIERC20.sol";
import {SIERC20Metadata} from "./SIERC20Metadata.sol";
import {Context} from "../openzeppelin/utils/Context.sol";
import {IERC20Errors} from "../openzeppelin/interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the {SIERC20} interface with privacy protections using shielded types.
 * Public view functions that would leak privacy are implemented as no-ops while maintaining interface compatibility.
 * Total supply remains public while individual balances and transfers are private.
 * Currently, this implementation is fully compliant with the ERC-20 standard, meaning that transfer recipients are NOT shielded/private.
 * Recipient addresses appear in the Transfer event as unshielded addresses.
 */
abstract contract SERC20 is Context, SIERC20, SIERC20Metadata, IERC20Errors {
    mapping(saddress account => suint256) private _balances;
    mapping(saddress account => mapping(saddress spender => suint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {SIERC20-balanceOf} and {SIERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {SIERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {SIERC20-balanceOf}.
     * Returns the balance of the caller if `account` matches the caller's address,
     * returns 0 otherwise to maintain privacy.
     */
    function balanceOf(saddress account) public view virtual override returns (uint256) {
        if (account == saddress(_msgSender())) {
            return uint256(_balances[account]);
        }
        return 0;
    }

    /**
     * @dev Transfers a shielded `value` amount of tokens to a shielded `to` address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     *
     * Note: Both `to` and `value` are shielded to maintain privacy.
     */
    function transfer(saddress to, suint256 value) public virtual override returns (bool) {
        saddress owner = saddress(_msgSender());
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {SIERC20-allowance}.
     * Returns actual allowance if caller is either the owner or the spender,
     * returns 0 otherwise to maintain privacy.
     */
    function allowance(saddress owner, saddress spender) public virtual view returns (uint256) {
        saddress caller = saddress(_msgSender());
        if (caller == owner || caller == spender) {
            return uint256(_allowances[saddress(owner)][saddress(spender)]);
        }
        return 0;
    }

    /**
     * @dev Approves a shielded `spender` to spend a shielded `value` amount of tokens on behalf of the caller.
     *
     * NOTE: If `value` is the maximum `suint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     *
     * Note: Both `spender` and `value` are shielded to maintain privacy.
     */
    function approve(saddress spender, suint256 value) public virtual override returns (bool) {
        saddress owner = saddress(_msgSender());
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev Transfers a shielded `value` amount of tokens from a shielded `from` address to a shielded `to` address.
     *
     * Skips emitting an {Approval} event indicating an allowance update to maintain privacy.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `suint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     *
     * Note: All parameters are shielded to maintain privacy.
     */
    function transferFrom(saddress from, saddress to, suint256 value) public virtual returns (bool) {
        saddress spender = saddress(_msgSender());
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to a shielded `spender` by a shielded `addedValue`.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {SIERC20-approve}.
     *
     * The operation is atomic - it directly accesses and modifies the underlying
     * shielded allowance mapping to prevent race conditions.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - The sum of current allowance and `addedValue` must not overflow.
     *
     * Note: Both `spender` and `addedValue` are shielded to maintain privacy.
     */
    function increaseAllowance(saddress spender, suint256 addedValue) public virtual returns (bool) {
        saddress owner = saddress(_msgSender());
        suint256 currentAllowance = _allowances[owner][spender];
        _approve(owner, spender, currentAllowance + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to a shielded `spender` by a shielded `subtractedValue`.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {SIERC20-approve}.
     *
     * The operation is atomic - it directly accesses and modifies the underlying
     * shielded allowance mapping to prevent race conditions.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - The current allowance must be greater than or equal to `subtractedValue`.
     * - The difference between the current allowance and `subtractedValue` must not underflow.
     *
     * Note: Both `spender` and `subtractedValue` are shielded to maintain privacy.
     */
    function decreaseAllowance(saddress spender, suint256 subtractedValue) public virtual returns (bool) {
        saddress owner = saddress(_msgSender());
        suint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance < subtractedValue) {
            revert ERC20InsufficientAllowance(address(spender), 0, 0);
        }
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    /**
     * @dev Moves a shielded `value` amount of tokens from a shielded `from` to a shielded `to` address.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event with zero values to maintain privacy.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(saddress from, saddress to, suint256 value) internal {
        if (from == saddress(address(0))) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == saddress(address(0))) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(saddress from, saddress to, suint256 value) internal virtual {
        _beforeTokenTransfer(from, to, value);

        if (from == saddress(address(0))) {
            // Convert from shielded to unshielded for total supply
            _totalSupply += uint256(value);
        } else {
            suint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(address(from), uint256(0), uint256(0)); // Zero values to protect privacy
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == saddress(address(0))) {
            unchecked {
                // Convert from shielded to unshielded for total supply
                _totalSupply -= uint256(value);
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(address(from), address(0), uint256(0)); // Zero value to protect privacy

        _afterTokenTransfer(from, to, value);
    }

    /**
     * @dev Creates a shielded `value` amount of tokens and assigns them to a shielded `account`.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with zero values to maintain privacy.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(saddress account, suint256 value) internal {
        if (account == saddress(address(0))) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(saddress(address(0)), account, value);
    }

    /**
     * @dev Destroys a shielded `value` amount of tokens from a shielded `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(saddress account, suint256 value) internal {
        if (account == saddress(address(0))) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, saddress(address(0)), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(saddress owner, saddress spender, suint256 value) internal {
        _approve(owner, spender, value, sbool(true));
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(saddress owner, saddress spender, suint256 value, sbool emitEvent) internal virtual {
        if (owner == saddress(address(0))) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == saddress(address(0))) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            // emit Approval(address(owner), address(spender), uint256(0)); // Zero value to protect privacy
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(saddress owner, saddress spender, suint256 value) internal virtual {
        suint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance < type(suint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(address(spender), uint256(0), uint256(0)); // Zero values to protect privacy
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, sbool(false));
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `value` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `value` tokens will be minted for `to`.
     * - when `to` is zero, `value` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * Note: The `value` parameter is a shielded uint256 to maintain privacy.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(saddress from, saddress to, suint256 value) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `value` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `value` tokens have been minted for `to`.
     * - when `to` is zero, `value` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * Note: The `value` parameter is a shielded uint256 to maintain privacy.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(saddress from, saddress to, suint256 value) internal virtual {}
}
