//SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

// **************************** Imports **************************** 

import "hardhat/console.sol";
import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider } from "./Interfaces.sol";

// **************************** Interfaces **************************** 

interface Meebit {
  function mintWithPunkOrGlyph(uint256 _createVia) external returns ( uint256 );
  function safeTransferFrom ( address _from, address _to, uint256 _tokenId ) external;
}

interface IWETHExtended is IWETH {
  function approve(address spender, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
}

interface INFTX {
  function redeem(uint256 vaultId, uint256 numNFTs) external payable;
}

interface IWPunks {
  function balanceOf(address account) external view returns (uint256);
  function burn(uint256 punkIndex) external;
}

interface IPunks {
  function punkIndexToAddress(uint256 index) external view returns (address);
  function transferPunk(address to, uint punkIndex) external;
  function balanceOf(address account) external view returns (uint256);
}

interface ERC721TokenReceiver
{
  function onERC721Received(
    address _operator,
    address _from,
    uint256 _tokenId,
    bytes calldata _data
  )
    external
    returns(bytes4);
}

contract Arb is FlashLoanReceiverBase, ERC721TokenReceiver {
  uint wrappedPunkId;
  uint meebitId;
  IWETHExtended private WETH = IWETHExtended(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IUniswapV2Router02 private router = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
  IERC20 private PUNKBASIC = IERC20(0x69BbE2FA02b4D90A944fF328663667DC32786385);
  INFTX private nftx = INFTX(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e);
  IWPunks private wpunks = IWPunks(0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6);
  IPunks private punks = IPunks(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);

  constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

  function redeemMeebit(uint256 _punkId) public {
   //punks.transferPunk(msg.sender, _punkId);
    punks.transferPunk(0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE, _punkId);
    console.log("Punk count for %s: %s", msg.sender, punks.balanceOf(address(msg.sender)));
    Meebit MainContract = Meebit(0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7);
    MainContract.mintWithPunkOrGlyph(_punkId);
    //Meebit.safeTransferFrom(address(this), msg.sender, _punkId);
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
    console.log("ETH Balance after flash loan is executed: %s\n", address(this).balance);

    // Swap for PUNK-BASIC
    //WETH.approve(address(router), 25000000000000000000);
    address[] memory path = new address[](3);
    path[0] = router.WETH();
    path[1] = address(0x87d73E916D7057945c9BcD8cdd94e42A6F47f776); // NFTX
    path[2] = address(0x69BbE2FA02b4D90A944fF328663667DC32786385);
    uint[] memory amounts = router.swapExactETHForTokens{value: 20610000000000000000}(0, path, address(this), block.timestamp);

    console.log("PUNK-BASIC balance after swap: %s", PUNKBASIC.balanceOf(address(this)));
    console.log("ETH balance after swap: %s\n", address(this).balance);

    PUNKBASIC.approve(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e, uint(-1));
    nftx.redeem(0, 1);

    // Swap return path
    path[0] = address(0x69BbE2FA02b4D90A944fF328663667DC32786385);
    path[2] = router.WETH();

    PUNKBASIC.approve(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e, uint(-1));
    router.swapExactTokensForETH(PUNKBASIC.balanceOf(address(this)), 19000000000000000000, path, address(this), block.timestamp);

    // Returned approx 19.298
    WETH.deposit{value:20628549000000000000}();
    console.log("PUNK-BASIC balance before repayment: %s", PUNKBASIC.balanceOf(address(this)));
    console.log("ETH Balance before repayment: %s", address(this).balance);
    console.log("WETH Balance before repayment: %s", WETH.balanceOf(address(this)));

    // Repay loan
    uint amountOwing = amounts[0].add(premiums[0]);
    console.log("Amount owed is %s", amountOwing);
    WETH.approve(address(LENDING_POOL), amountOwing);

    // Return flash loan success
    return true;
  }

  function executeFlashLoan() public {
    console.log("My Address: %s", msg.sender);
    console.log("ETH Balance before flash loan is executed: %s", address(this).balance);
    address receiverAddress = address(this);

    address[] memory assets = new address[](1);
    assets[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 20.61 ether;

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

  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
    console.log("%s, %s", operator, from);
    if (from == 0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e) {
      wrappedPunkId = tokenId;
      console.log("Received wrapped punk: %s", tokenId);
      //require(tokenId == 4960 || tokenId == 8208 || tokenId == 8078, "Meebit not available");
      wpunks.burn(wrappedPunkId);
      console.log("Punk owner: %s", punks.punkIndexToAddress(wrappedPunkId));
      console.log("Punk count: %s", punks.balanceOf(address(this)));
      redeemMeebit(wrappedPunkId);
    }

    if (from == 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7) {
      meebitId = tokenId;
      console.log("Received meebit: %s", meebitId);
    }
    
    return 0x150b7a02;
  }
}