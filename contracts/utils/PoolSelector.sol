// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interfaces/IUniswapV3Factory.sol";
import "../interfaces/IUniswapV3Pool.sol";

contract PoolSelector {
    IUniswapV3Factory public uniswapFactory;

    constructor(address _factory) {
        uniswapFactory = IUniswapV3Factory(_factory);
    }

    function getBestPool(
        address tokenIn,
        address tokenOut
    ) public view returns (address) {
        uint24[4] memory fees = [
            uint24(500),
            uint24(2500),
            uint24(3000),
            uint24(10000)
        ];
        address bestPool = address(0);
        uint128 highestLiquidity = 0;

        for (uint256 i = 0; i < fees.length; i++) {
            address poolAddress = uniswapFactory.getPool(
                tokenIn,
                tokenOut,
                fees[i]
            );
            if (poolAddress != address(0)) {
                IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
                uint128 liquidity = pool.liquidity();
                if (liquidity > highestLiquidity) {
                    highestLiquidity = liquidity;
                    bestPool = poolAddress;
                }
            }
        }

        return bestPool;
    }
}
