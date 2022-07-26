const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");
describe("test nft marketplace", () => {
  const PRICE = ethers.utils.parseEther("0.5");
  const newPrice = ethers.utils.parseEther("0.55");
  let marketplace, nft;
  beforeEach(async () => {
    accounts = await ethers.getSigners();
    seller = accounts[0];
    buyer = accounts[1];
    marketplaceFeeCollector = accounts[2];
    collectionFeeCollector = accounts[3];
    await deployments.fixture(["all"]);
    nft = await ethers.getContract("TestERC721");
    marketplace = await ethers.getContract("NftMarketplace");
    await marketplace.setMarketplaceFeeCollector(
      marketplaceFeeCollector.address
    );
    await marketplace.setMarketplaceFee(2);
    await marketplace.setCollectionDetails(
      nft.address,
      5,
      collectionFeeCollector.address
    );
  });
  describe("Test Erc721", () => {
    it("Check balance", async () => {
      expect(await nft.balanceOf(buyer.address)).to.equal(5);
      expect(await nft.balanceOf(seller.address)).to.equal(5);
    });
  });
  describe("nft marketplace", () => {
    it("Create Listing", async () => {
      ///
      await expect(
        marketplace
          .connect(seller)
          .createListing(nft.address, 1, PRICE, 1658848011)
      ).to.be.revertedWith("InvalidExpirationTime()");
      await expect(
        marketplace
          .connect(seller)
          .createListing(nft.address, 1, 0, 16588480111)
      ).to.be.revertedWith("PriceCannotBeZero()");
      await expect(
        marketplace
          .connect(seller)
          .createListing(nft.address, 6, PRICE, 16588480111)
      ).to.be.revertedWith("NotOwner()");
      await expect(
        marketplace
          .connect(seller)
          .createListing(nft.address, 4, PRICE, 16588480111)
      ).to.be.revertedWith("NotApproved()");
      await nft.connect(seller).setApprovalForAll(marketplace.address, true);
      expect(
        await marketplace
          .connect(seller)
          .createListing(nft.address, 4, PRICE, 16588480111)
      ).to.emit("ItemListed");
      await expect(
        marketplace
          .connect(seller)
          .createListing(nft.address, 4, PRICE, 16588480111)
      ).to.be.revertedWith("AlreadyListed()");
    });
  });
  describe("update listing", () => {
    it("update listing", async () => {
      await nft.connect(seller).setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace.connect(seller).updateListing(nft.address, 4, PRICE)
      ).to.be.revertedWith("NotListed()");
      await marketplace
        .connect(seller)
        .createListing(nft.address, 4, PRICE, 16588480111);
      await expect(
        marketplace.connect(seller).updateListing(nft.address, 4, PRICE)
      ).to.be.revertedWith("PriceCannotBeTheSame()");
      await marketplace.connect(seller).updateListing(nft.address, 4, newPrice);
    });
  });
  describe("cancel listing", () => {
    it("cancel listing", async () => {
      await nft.connect(seller).setApprovalForAll(marketplace.address, true);
      await nft.connect(buyer).setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace.connect(seller).cancelListing(nft.address, 1)
      ).to.be.revertedWith("NotListed()");
      await marketplace
        .connect(seller)
        .createListing(nft.address, 1, PRICE, 16588480111);
      await marketplace
        .connect(buyer)
        .createListing(nft.address, 6, PRICE, 16588480111);
      await expect(
        marketplace.connect(seller).cancelListing(nft.address, 6)
      ).to.be.revertedWith("NotOwner()");
      await marketplace.connect(seller).cancelListing(nft.address, 1);
    });
  });
  describe("Buy Item", () => {
    it("buy item", async () => {
      await nft.connect(seller).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(seller)
        .createListing(nft.address, 1, PRICE, 16588480111);
      await marketplace
        .connect(buyer)
        .buyItem(nft.address, 1, { value: PRICE });
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
    });
  });
});
