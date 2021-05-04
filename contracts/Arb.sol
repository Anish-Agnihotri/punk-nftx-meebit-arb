//SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

// ============ Imports ============

import "hardhat/console.sol";
import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider } from "./Interfaces.sol";

// ============ Interfaces ============

// Meebit (extracted from ABI in shipped VueJS)
interface Meebit {
  function mintWithPunkOrGlyph(uint256 _createVia) external returns ( uint256 );
  function safeTransferFrom ( address _from, address _to, uint256 _tokenId ) external;
}

// Uniswap IWETH extended with balanceOf + approve
interface IWETHExtended is IWETH {
  function approve(address spender, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
}

// NFTX
interface INFTX {
  function redeem(uint256 vaultId, uint256 numNFTs) external payable;
}

// Wrapped Punks
interface IWPunks {
  function balanceOf(address account) external view returns (uint256);
  function burn(uint256 punkIndex) external;
}

// CryptoPunks
interface IPunks {
  function punkIndexToAddress(uint256 index) external view returns (address);
  function transferPunk(address to, uint punkIndex) external;
  function balanceOf(address account) external view returns (uint256);
}

// Recipient for ERC721 tokens from contract
interface ERC721TokenReceiver {
  function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}

contract Arb is FlashLoanReceiverBase, ERC721TokenReceiver {
  
  // ============ Mutable storage ============

  uint wrappedPunkId;
  uint meebitId;

  // ============ Private constants ============

  IWETHExtended private WETH = IWETHExtended(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IUniswapV2Router02 private router = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
  IERC20 private PUNKBASIC = IERC20(0x69BbE2FA02b4D90A944fF328663667DC32786385);
  INFTX private nftx = INFTX(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e);
  IWPunks private wpunks = IWPunks(0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6);
  IPunks private punks = IPunks(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
  Meebit private MainContract = Meebit(0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7);

  // ============ Constructor ============

  constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

  // ============ Functions ============

  /**
   * Redeem Meebit using punk
   */
  function redeemMeebit(uint256 _punkId) public {
   //punks.transferPunk(msg.sender, _punkId);
    //punks.transferPunk(0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE, _punkId);
    //console.log("Punk count for %s: %s", msg.sender, punks.balanceOf(address(msg.sender)));
    MainContract.mintWithPunkOrGlyph(_punkId);
    //Meebit.safeTransferFrom(address(this), msg.sender, _punkId);
  }

  /**
   * Post flash loan execution
   */
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
    // Convert flash-loaned wETH to ETH
    WETH.withdraw(WETH.balanceOf(address(this)));
    console.log("ETH Balance after flash loan is executed: %s\n", address(this).balance);

    // Swap for PUNK-BASIC
    address[] memory path = new address[](3);

    // SushiSwap (ETH -> WETH -> NFTX -> PUNK-BASIC) path
    path[0] = router.WETH();
    path[1] = address(0x87d73E916D7057945c9BcD8cdd94e42A6F47f776); // NFTX
    path[2] = address(0x69BbE2FA02b4D90A944fF328663667DC32786385);

    // Swap for approximately 1 PUNK-BASIC
    uint[] memory amounts = router.swapExactETHForTokens{value: 20610000000000000000}(0, path, address(this), block.timestamp);
    console.log("PUNK-BASIC balance after swap: %s", PUNKBASIC.balanceOf(address(this)));
    console.log("ETH balance after swap: %s\n", address(this).balance);

    // Redeem PUNK-BASIC for a wrapped cryptopunk
    PUNKBASIC.approve(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e, uint(-1));
    nftx.redeem(0, 1); // Calls onERC721Received

    // Swap return (PUNK-BASIC -> NFTX -> WETH -> ETH) path
    path[0] = address(0x69BbE2FA02b4D90A944fF328663667DC32786385);
    path[2] = router.WETH();

    // Infinite approve and swap
    PUNKBASIC.approve(0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e, uint(-1));
    router.swapExactTokensForETH(PUNKBASIC.balanceOf(address(this)), 19000000000000000000, path, address(this), block.timestamp);

    // Collect funds to repay flash loan
    WETH.deposit{value:20628549000000000000}();
    console.log("PUNK-BASIC balance before repayment: %s", PUNKBASIC.balanceOf(address(this)));
    console.log("ETH Balance before repayment: %s", address(this).balance);
    console.log("WETH Balance before repayment: %s", WETH.balanceOf(address(this)));

    // Repay flash loan
    uint amountOwing = amounts[0].add(premiums[0]);
    console.log("Amount owed is %s", amountOwing);
    WETH.approve(address(LENDING_POOL), amountOwing);

    // Return flash loan success
    return true;
  }

  /**
   * Execute Aave flash loan
   */
  function executeFlashLoan() public {
    console.log("My Address: %s", msg.sender);
    console.log("ETH Balance before flash loan is executed: %s", address(this).balance);
    address receiverAddress = address(this);

    // Borrow wETH
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

  // Make contract payable to receive funds
  event Received(address, uint);
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /**
   * Receive wrapped cryptopunk
   */
  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
    console.log("%s, %s", operator, from);

    // If wrapped crypto punk
    if (from == 0xAf93fCce0548D3124A5fC3045adAf1ddE4e8Bf7e) {
      wrappedPunkId = tokenId;
      console.log("Received wrapped punk: %s", tokenId);

      // This require forces redemption of only CryptoPunks that allow Meebit redemption
      //require(tokenId == 4960 || tokenId == 8208 || tokenId == 8078, "Meebit not available");

      // Unwrap crytopunk
      wpunks.burn(wrappedPunkId);
      console.log("Punk owner: %s", punks.punkIndexToAddress(wrappedPunkId));
      console.log("Punk count: %s", punks.balanceOf(address(this)));

      // Redeem meebit
      redeemMeebit(wrappedPunkId);
    }

    // TODO: logic to send Meebit to msg.sender
    
    return 0x150b7a02;
  }
}