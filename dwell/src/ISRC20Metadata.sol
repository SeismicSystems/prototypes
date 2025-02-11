// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.20;

import {ISRC20} from "./ISRC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface ISRC20Metadata is ISRC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}
