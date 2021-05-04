// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.6.6;

import { SafeERC20, SafeMath } from "./Libraries.sol";
import { IFlashLoanReceiver, ILendingPoolAddressesProvider, ILendingPool, IERC20 } from "./Interfaces.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  ILendingPool public immutable LENDING_POOL;

  constructor(ILendingPoolAddressesProvider provider) public {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
  }
}