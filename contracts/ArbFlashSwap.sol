//SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';

import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import '@uniswap/v2-periphery/contracts/interfaces/V1/IUniswapV1Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/V1/IUniswapV1Exchange.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IWETH.sol';

contract ArbFlashSwap is IUniswapV2Callee {
  IUniswapV1Factory immutable factoryV1;
  address immutable factory;
  IWETH immutable WETH;

  constructor(address _factory, address _factoryV1, address router) public {
    factoryV1 = IUniswapV1Factory(_factoryV1);
    factory = _factory;
    WETH = IWETH(IUniswapV2Router01(router).WETH());
  }

  receive() external payable {}

  // gets tokens/WETH via a V2 flash swap, swaps for the ETH/tokens on V1, repays V2, and keeps the rest!
  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
    address[] memory path = new address[](2);
    uint amountToken;
    uint amountETH;

    { // scope for token{0,1}, avoids stack too deep errors
      address token0 = IUniswapV2Pair(msg.sender).token0();
      address token1 = IUniswapV2Pair(msg.sender).token1();
      assert(msg.sender == UniswapV2Library.pairFor(factory, token0, token1)); // ensure that msg.sender is actually a V2 pair
      assert(amount0 == 0 || amount1 == 0); // this strategy is unidirectional
      path[0] = amount0 == 0 ? token0 : token1;
      path[1] = amount0 == 0 ? token1 : token0;
      amountToken = token0 == address(WETH) ? amount1 : amount0;
      amountETH = token0 == address(WETH) ? amount0 : amount1;
    }

    assert(path[0] == address(WETH) || path[1] == address(WETH)); // this strategy only works with a V2 WETH pair
    IERC20 token = IERC20(path[0] == address(WETH) ? path[1] : path[0]);
    IUniswapV1Exchange exchangeV1 = IUniswapV1Exchange(factoryV1.getExchange(address(token))); // get V1 exchange

    uint amountRequired = UniswapV2Library.getAmountsIn(factory, amountToken, path)[0];
    console.log("Repay required: %s", amountRequired);
    //WETH.deposit{value: amountRequired}();
    assert(WETH.transfer(msg.sender, amountRequired)); // return WETH to V2 pair
    //(bool success,) = sender.call{value: amountReceived - amountRequired}(new bytes(0)); // keep the rest! (ETH)
    //assert(success);
  }
}