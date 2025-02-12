// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {ISRC20} from "./SRC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title InternalAMM - Restricted Access Automated Market Maker
/// @notice A constant product AMM (x*y=k) that manages the liquidity pool for the DePIN price floor protocol
/// @dev Uses shielded data types (suint256) for privacy-preserving calculations
/// @dev All operations are restricted to the owner to so that even properties relevent to the caller,
//       e.g. price, can't be observed until the owner wishes to reveal them
contract InternalAMM is Ownable(msg.sender) {
    ISRC20 public token0;
    ISRC20 public token1;

    suint256 reserve0;
    suint256 reserve1;

    suint256 totalSupply;
    mapping(address => suint256) balanceOf;

    /// @notice Initializes the AMM with token pair addresses
    /// @param _token0 Address of the first token (typically WDG)
    /// @param _token1 Address of the second token (typically USDC)
    constructor(address _token0, address _token1) {
        token0 = ISRC20(_token0);
        token1 = ISRC20(_token1);
    }

    function _mint(address _to, suint256 _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, suint256 _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(suint256 _reserve0, suint256 _reserve1) internal {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    /// @notice Calculates amount of token0 received after a liquidation
    /// @dev Uses constant product formula to determine price impact
    /// @param _amount0 Amount of token0 to be liquidated
    /// @return Average price of token0 denominated in token1
    function calcSwapOutput(suint256 _amount0) external view onlyOwner returns (uint256) {
        /* XY = K
        (X+dX)(Y-dY) = K
        dY = Y - K / (X+dX)
        dY = YdX/(X+dX) = Y(1-X/(X+dX))

        Return dY = dX * Y / (X+dX) 
         */

        return uint256(reserve1 / (reserve0 / _amount0 + suint(1)));
    }

    /// @notice Calculates required input amount for desired output
    /// @dev Reverse calculation of constant product formula
    /// @param _tokenOut Address of token to receive
    /// @param _amount Desired output amount
    /// @return amountIn of input token required to achieve desired output
    function calcSwapInput(address _tokenOut, suint256 _amount) public view onlyOwner returns (uint256) {
        /* XY = K
        (X+dX)(Y-dY) = K
        dY = Y - K / (X+dX)
        dY = YdX/(X+dX) = Y(1-X/(X+dX))

        Return dX = X dY / (Y-dY)
        */
        suint256 amountIn = _tokenOut == address(token1)
            ? reserve0 / (reserve1 / _amount - suint(1))
            : reserve1 / (reserve0 / _amount - suint(1));

        return uint256(amountIn);
    }

    /// @notice Adds liquidity to the AMM pool
    /// @dev Maintains price ratio for existing pools
    /// @param _amount0 Amount of token0 to add
    /// @param _amount1 Amount of token1 to add
    /// @param originalSender Address to receive LP tokens
    function addLiquidity(suint256 _amount0, suint256 _amount1, address originalSender) external onlyOwner {
        token0.transferFrom(saddress(msg.sender), saddress(this), _amount0);
        token1.transferFrom(saddress(msg.sender), saddress(this), _amount1);

        if (reserve0 > suint256(0) || reserve1 > suint256(0)) {
            require(
                reserve0 * _amount1 == reserve1 * _amount0, //preserving price
                "x / y != dx / dy"
            );
        }
        // if i wanted to put usdc into the pool, first swap until the ratios

        suint256 shares = totalSupply == suint(0)
            ? _sqrt(_amount0 * _amount1)
            : _min((_amount0 * totalSupply) / reserve0, (_amount1 * totalSupply) / reserve1);

        require(shares > suint256(0), "No shares to mint");
        _mint(originalSender, shares);

        // recalculate k
        _update(suint256(token0.balanceOf()), suint256(token1.balanceOf()));
    }

    /// @notice Removes liquidity from the AMM pool
    /// @dev Burns LP tokens and returns underlying assets
    /// @param _shares Amount of LP tokens to burn
    /// @param originalSender Address that owns the LP tokens
    function removeLiquidity(suint256 _shares, address originalSender) external onlyOwner {
        require(balanceOf[originalSender] > _shares, "Insufficient shares");
        suint256 amount0 = (_shares * reserve0) / totalSupply;
        suint256 amount1 = (_shares * reserve1) / totalSupply;
        require(amount0 > suint256(0) && amount1 > suint256(0), "amount0 or amount1 = 0");

        _burn(originalSender, _shares); // burn LP shares
        _update(reserve0 - amount0, reserve1 - amount1);

        token0.transfer(saddress(msg.sender), amount0);
        token1.transfer(saddress(msg.sender), suint(amount1));
    }

    /// @notice Executes token swap using constant product formula
    /// @dev Updates reserves after swap completion
    /// @param _tokenIn Address of input token
    /// @param _amountIn Amount of input token
    function swap(saddress _tokenIn, suint256 _amountIn) external onlyOwner {
        require(_amountIn > suint(0), "Invalid amount to swap");
        require(_tokenIn == saddress(token0) || _tokenIn == saddress(token1), "Invalid token");

        bool isToken0 = _tokenIn == saddress(token0);

        (ISRC20 tokenIn, ISRC20 tokenOut, suint256 reserveIn, suint256 reserveOut) =
            isToken0 ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);

        tokenIn.transferFrom(saddress(msg.sender), saddress(this), _amountIn);

        suint256 amountOut = reserveOut * _amountIn / (reserveIn + _amountIn); // still shielded

        tokenOut.approve(saddress(this), amountOut);
        tokenOut.transferFrom(saddress(this), saddress(msg.sender), amountOut);

        _update(suint256(token0.balanceOf()), suint256(token1.balanceOf()));
    }

    /// @notice Executes token swap by taking token out of the pool.
    ///  This is ONLY called within operatorWithdraw, where the owed balance
    ///  is first transferred to the AMM.
    /// @dev Updates reserves after swap completion.
    function swapOut(saddress _tokenOut, suint256 _amountOut) external onlyOwner {
        require(_tokenOut == saddress(token0) || _tokenOut == saddress(token1), "Invalid token");

        bool isToken0 = _tokenOut == saddress(token0);

        (ISRC20 tokenOwed, ISRC20 tokenRm, suint256 reserveRm) =
            isToken0 ? (token1, token0, reserve0) : (token0, token1, reserve1);

        require(_amountOut <= reserveRm, "Invalid amount to extract.");

        suint256 amountOwed = suint256(calcSwapInput(address(tokenRm), _amountOut));

        tokenOwed.transferFrom(saddress(msg.sender), saddress(this), amountOwed);

        tokenRm.approve(saddress(this), _amountOut);
        tokenRm.transferFrom(saddress(this), saddress(msg.sender), _amountOut);

        _update(suint256(token0.balanceOf()), suint256(token1.balanceOf()));
    }

    /// @notice Calculates square root using binary search
    /// @dev Used for initial LP token minting
    /// @param y Value to find square root of
    /// @return z Square root of input value
    function _sqrt(suint256 y) private pure returns (suint256 z) {
        if (y < suint256(3)) {
            z = y;
            suint256 x = y / suint256(2) + suint256(1);
            while (x < z) {
                z = x;
                x = (y / x + x) / suint256(2);
            }
        } else if (y != suint256(0)) {
            z = suint256(1);
        }
    }

    /// @notice Returns minimum of two values
    /// @param x First value
    /// @param y Second value
    /// @return Smaller of the two inputs
    function _min(suint256 x, suint256 y) private pure returns (suint256) {
        return x <= y ? x : y;
    }
}
