require("@nomiclabs/hardhat-waffle");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	solidity: "0.6.6",
	networks: {
		hardhat: {
			forking: {
				url:
					"https://eth-mainnet.alchemyapi.io/v2/DlK2Z6YPuqyDASJD1JSL8I1T_dYtposw",
				blockNumber: 12363929,
			},
		},
	},
};
