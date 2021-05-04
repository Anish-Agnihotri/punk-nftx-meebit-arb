const { ethers } = require("hardhat");

describe("Use NFTX punks to redeem Meebits", function () {
  it("Should redeem available Meebits", async function () {
    // Impersonate Binance
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be"],
    });
    const signer = await ethers.provider.getSigner(
      "0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be"
    );

    // Deploy contract
    const Arb = await ethers.getContractFactory("Arb");
    const arb = await Arb.deploy("0xb53c1a33016b2dc2ff3653530bff1848a515c8c5");
    const tx = await arb.deployed();
    const contractAddress = tx.deployTransaction.creates;

    // Send extra fees to cover diff in buy/sell
    await signer.sendTransaction({
      to: contractAddress,
      value: ethers.utils.parseEther("1.330549"),
    });

    // Execute flash loan
    const impersonatedContract = arb.connect(signer);
    await impersonatedContract.executeFlashLoan();
  });
});
