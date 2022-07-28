const { network } = require("hardhat");
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId === 31337) {
    log("Deploying.......");
    const testErc721 = await deploy("TestERC721", {
      from: deployer,
      args: [],
      log: true,
    });
    log(
      `TestERC721 contract successfully deployed to ${testErc721.address}`
    );
  }
};

module.exports.tags = ["all", "marketplace"];
