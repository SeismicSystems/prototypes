// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC, modified for shielded types.
 */
interface SIERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     * For privacy reasons, returns actual balance only if caller is the account owner,
     * otherwise returns 0.
     */
    function balanceOf(saddress account) external view returns (uint256);

    /**
     * @dev Moves a shielded `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event with zero values to maintain privacy.
     */
    function transfer(saddress to, suint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     * For privacy reasons, returns actual allowance only if caller is either owner or spender,
     * otherwise returns 0.
     */
    function allowance(saddress owner, saddress spender) external view returns (uint256);

    /**
     * @dev Sets a shielded `value` amount of tokens as the allowance of a shielded `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits an {Approval} event with zero values to maintain privacy.
     */
    function approve(saddress spender, suint256 value) external returns (bool);

    /**
     * @dev Moves a shielded `value` amount of tokens from a shielded `from` address to a shielded `to` address using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event with zero values to maintain privacy.
     */
    function transferFrom(saddress from, saddress to, suint256 value) external returns (bool);
}
