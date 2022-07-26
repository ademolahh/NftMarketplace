module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("Deploying.......");
  const nftMarketplace = await deploy("NftMarketplace", {
    from: deployer,
    args: [],
    log: true,
  });
  log(
    `NFT Markeplace contract successfully deployed to ${nftMarketplace.address}`
  );
};

module.exports.tags = ["all", "marketplace"];
