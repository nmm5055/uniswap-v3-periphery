// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
import '@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol';

import '../base/PeripheryPayments.sol';
import '../base/PeripheryImmutableState.sol';

import '../libraries/PoolAddress.sol';
import '../libraries/CallbackValidation.sol';


contract FlashLoan is IUniswapV3FlashCallback, PeripheryImmutableState, PeripheryPayments {
    using LowGasSafeMath for uint256;

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);
        
        // do the flash loan arb/use case stuff here
    
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
        uint24 fee;
        address recipient;
        uint256 amount0;
        uint256 amount1;
    }

        struct FlashCallbackData {
        uint256 amount0;
        uint256 amount1;
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    //return?
    function initFlash(FlashParams memory params) external {

        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        // recipient of borrowed amounts
        // amount of token0 requested to borrow
        // amount of token1 requested to borrow
        // need amount 0 and amount1 in callback to pay back pool
        pool.flash(
            params.recipient,
            params.amount0,
            params.amount1,
            abi.encode(FlashCallbackData({amount0: params.amount0, amount1: params.amount1, poolKey: poolKey, payer: msg.sender}))
        );
    }

}
