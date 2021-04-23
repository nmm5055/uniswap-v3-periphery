// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
import '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';

import '../base/PeripheryPayments.sol';
import '../base/PeripheryImmutableState.sol';

import '../libraries/PoolAddress.sol';
import '../libraries/CallbackValidation.sol';
import '../SwapRouter.sol';
import '../interfaces/ISwapRouter.sol';


abstract contract FlashLoan is IUniswapV3FlashCallback, PeripheryPayments, PeripheryImmutableState {
    using LowGasSafeMath for uint256;

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashCallbackData memory data = abi.decode(data, (FlashCallbackData));
        CallbackValidation.verifyCallback(factory, data.poolKey);

        //(address token0, address token1, uint24 fee1) = data.path.decodeFirstPool();
        

        // call exactInput with the path for both swaps
        ExactInputParams inputParamsSwapOne = ExactInputParams({path: data.path1, recipient: data.payer, deadline: 0, amountIn: data.amount0, amountOutMinimum: data.amount0});

        ExactInputParams inputParamsSwapTwo = ExactInputParams({path: data.path2, recipient: data.payer, deadline: 0, amountIn: data.amount1, amountOutMinimum: data.amount1});
        
        // call exactInput for swapping token1 for token0 in pool w/fee1
        uint256 amountOut0 = exactInput(inputParamsSwapOne);

        // call exactInputfor swapping token0 for token 1 in pool w/fee2
        uint256 amountOut1 = exactInput(inputParamsSwapTwo);

        // end up with amountOut0 of token0 from first swap and amountOut1 of token1 from second swap

        // require profitable (amountOut0 - fee0 > amount0 && amountOut1 - fee1 > amount1)

        // pay back amount0 + fee0 and amount1 + fee1 to original pool (poolKey) and keep profits

        // pay original pool the amount of token0 plus fees and amount of token1 plus fees
        // with flash() must pay back the same token
        uint256 amount0Owed = LowGasSafeMath.add(decoded.amount0, fee0);
        uint256 amount1Owed = LowGasSafeMath.add(decoded.amount1, fee1);

        if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
    }

        struct FlashParams {
        address token0;
        address token1;
        uint24 fee0;
        address recipient;
        uint256 amount0;
        uint256 amount1;
        uint24 fee1;
        uint24 fee2;
    }
        // fee1 and fee2 are the two other fee pools associated with token0 and token1
        struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        address payer;
        PoolAddress.PoolKey poolKey;
        bytes path;
    }

    //return?
    function initFlash(FlashParams memory params) external {

        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee0});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        // recipient of borrowed amounts
        // amount of token0 requested to borrow
        // amount of token1 requested to borrow
        // need amount 0 and amount1 in callback to pay back pool

        bytes path1 = abi.encodePacked(params.token0, params.fee1, params.token1);
        bytes path2 = abi.encodePacked(params.token0, params.fee2, params.token1);
        
        pool.flash(
            params.recipient,
            params.amount0,
            params.amount1,
            abi.encode(FlashCallbackData({amount0: params.amount0, amount1: params.amount1, payer: msg.sender, poolKey: poolKey, path1: path1, path2: path2}))
        );
    }

}
