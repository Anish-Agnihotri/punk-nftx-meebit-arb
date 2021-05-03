const { ethers } = require("hardhat");

describe("Arb NFTX", function () {
	it("Should ARB", async function () {
		await hre.network.provider.request({
			method: "hardhat_impersonateAccount",
			params: ["0x062C5432107e3b9Ad924512209a7468B5C200fCd"],
		});
		const signer = await ethers.provider.getSigner(
			"0x062C5432107e3b9Ad924512209a7468B5C200fCd"
		);

		const Arb = await ethers.getContractFactory("Arb");
		const arb = await Arb.deploy("0xb53c1a33016b2dc2ff3653530bff1848a515c8c5");
		const tx = await arb.deployed();
		const contractAddress = tx.deployTransaction.creates;
		await signer.sendTransaction({
			to: contractAddress,
			value: ethers.utils.parseEther("1.0"),
		});

		const impersonatedContract = arb.connect(signer);
		await impersonatedContract.executeFlashLoan();
	});
});
