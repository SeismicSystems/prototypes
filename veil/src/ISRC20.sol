// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title ISRC20
/// @notice Interface for Seismic's shielded fungible token standard
interface ISRC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function balanceOf() external view returns (uint256);
    function approve(address spender, suint256 amount) external returns (bool);
    function transfer(address to, suint256 amount) external returns (bool);
    function transferFrom(address from, address to, suint256 amount) external returns (bool);
}
