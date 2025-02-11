// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.27;

/*
 * Assumption:
 * The custom types `saddress` and `suint256` are defined elsewhere.
 * They are identical in behavior to address and uint256 respectively,
 * but signal that the underlying data is stored privately.
 */

/*//////////////////////////////////////////////////////////////
//                        ISRC20 Interface
//////////////////////////////////////////////////////////////*/

interface ISRC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    // event Transfer(address indexed from, address indexed to, uint256 amount);
    // event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);

    /*//////////////////////////////////////////////////////////////
                              ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function balanceOf() external view returns (uint256);
    function transfer(saddress to, suint256 amount) external returns (bool);
    // owner passed in as msg.sender via signedRead
    function allowance(saddress spender) external view returns (uint256);
    function approve(saddress spender, suint256 amount) external returns (bool);
    function transferFrom(saddress from, saddress to, suint256 amount) external returns (bool);
}
