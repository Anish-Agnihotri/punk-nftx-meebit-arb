//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20 } from "./Interfaces.sol";
import { SafeMath } from "./Libraries.sol";

interface Meebit {
  function mintWithPunkOrGlyph(uint256 _createVia) external returns ( uint256 );
}

// Additional methods available for WETH
interface IWETH is IERC20 {
  function deposit() external payable;
  function withdraw(uint wad) external;
}

contract Arb is FlashLoanReceiverBase {
  using SafeMath for uint256;
  IWETH private WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

  function redeemMeebit(uint256 _punkId) public {
    Meebit MainContract = Meebit(0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7);
    MainContract.mintWithPunkOrGlyph(_punkId);
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  )
    external
    override
    returns (bool)
  {
    // Get ETH to account
    WETH.withdraw(WETH.balanceOf(address(this)));
    console.log("1. ETH Balance is %s", address(this).balance);

    WETH.deposit{value:25022500000000000000}();
    console.log("2. WETH Balance is %s", address(this).balance);

    // Repay loan
    uint amountOwing = amounts[0].add(premiums[0]);
    console.log("Amount owed is %s", amountOwing);
    WETH.approve(address(LENDING_POOL), amountOwing);

    return true;
  }

  function executeFlashLoan() public {
    console.log("ETH Balance before all execution is %s", address(this).balance);
    address receiverAddress = address(this);

    address[] memory assets = new address[](1);
    assets[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 25 ether;

    uint256[] memory modes = new uint256[](1);
    modes[0] = 0;

    address onBehalfOf = address(this);
    bytes memory params = "";
    uint16 referralCode = 0;

    LENDING_POOL.flashLoan(
      receiverAddress,
      assets,
      amounts,
      modes,
      onBehalfOf,
      params,
      referralCode
    );
  }

  event Received(address, uint);
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
}