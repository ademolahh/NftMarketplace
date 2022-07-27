// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NotOwner();
error NotListed();
error NotApproved();
error AboveMaximum();
error AlreadyListed();
error ListingExpired();
error YouOwnThisItem();
error TransferFailed();
error NotEnoughEther();
error LengthsNotEqual();
error PriceCannotBeZero();
error PriceCannotBeTheSame();
error InvalidExpirationTime();

contract NftMarketplace is ReentrancyGuard, Ownable {
    uint256 public MarketplaceFee;
    address public MarketplaceFeeCollector;

    uint256 public constant MARKETPLACE_MAX_FEE = 5;
    uint256 public constant COLLECTION_MAX_FEE = 12;

    struct ListingItem {
        uint256 price;
        uint256 expirationTime;
        address seller;
    }

    struct CollectionOwnerFee {
        uint256 fee;
        address receipt;
    }

    mapping(address => mapping(uint256 => ListingItem)) private listing;
    mapping(address => CollectionOwnerFee) private _collection;

    modifier notListed(address nftAddress, uint256 tokenId) {
        ListingItem memory _listing = listing[nftAddress][tokenId];
        if (_listing.price > 0) revert AlreadyListed();
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        ListingItem memory _listing = listing[nftAddress][tokenId];
        if (_listing.price <= 0) revert NotListed();
        _;
    }

    function _createListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _expirationTime
    ) private {
        if (_expirationTime <= block.timestamp) revert InvalidExpirationTime();
        if (_price <= 0) revert PriceCannotBeZero();
        IERC721 nft = IERC721(_nftAddress);
        if (nft.ownerOf(_tokenId) != msg.sender) revert NotOwner();
        if (!nft.isApprovedForAll(msg.sender, address(this)))
            revert NotApproved();
        listing[_nftAddress][_tokenId] = ListingItem({
            price: _price,
            expirationTime: _expirationTime,
            seller: msg.sender
        });
        console.log(
            "The token is",
            listing[_nftAddress][_tokenId].price,
            listing[_nftAddress][_tokenId].expirationTime,
            listing[_nftAddress][_tokenId].seller
        );
    }

    function createListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _expirationTime
    ) public notListed(_nftAddress, _tokenId) nonReentrant {
        _createListing(_nftAddress, _tokenId, _price, _expirationTime);
        emit ItemListed(msg.sender, _nftAddress, _tokenId, _price);
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 newPrice
    ) external isListed(_nftAddress, _tokenId) nonReentrant {
    if (listing[_nftAddress][_tokenId].expirationTime < block.timestamp) revert ListingExpired();
        if (listing[_nftAddress][_tokenId].price == newPrice)
            revert PriceCannotBeTheSame();
        listing[_nftAddress][_tokenId].price = newPrice;
        emit UpdateListing(msg.sender, _nftAddress, _tokenId, newPrice);
    }

    function cancelListing(address _nftAddress, uint256 _tokenId)
        external
        isListed(_nftAddress, _tokenId)
        nonReentrant
    {
        if (IERC721(_nftAddress).ownerOf(_tokenId) != msg.sender)
            revert NotOwner();
        delete listing[_nftAddress][_tokenId];
        emit ItemCanceled(msg.sender, _nftAddress, _tokenId);
    }

    function buyItem(address nftAddress, uint256 tokenId)
        public
        payable
        nonReentrant
        isListed(nftAddress, tokenId)
    {
        ListingItem memory _listing = listing[nftAddress][tokenId];
        uint256 _price = _listing.price;
        address _seller = _listing.seller;
        IERC721 nft = IERC721(nftAddress);
        if (_seller == msg.sender) revert YouOwnThisItem();
        if (_listing.expirationTime < block.timestamp) revert ListingExpired();
        if (msg.value < _price) revert NotEnoughEther();
        delete listing[nftAddress][tokenId];
        _makePayment(nftAddress, _seller, _price);
        nft.safeTransferFrom(_listing.seller, msg.sender, tokenId);
        emit ItemListed(_seller, nftAddress, tokenId, _price);
        console.log("The balance of the buyer", address(msg.sender).balance);
        console.log(
            "The balance of the seller",
            address(_listing.seller).balance
        );
    }

    function _makePayment(
        address nftAddress,
        address to,
        uint256 amount
    ) private {
        CollectionOwnerFee memory collection = _collection[nftAddress];
        uint256 collectionFee;
        uint256 _marketplaceFee;
        if (collection.receipt != address(0)) {
            collectionFee = collection.fee;
            _marketplaceFee = MarketplaceFee;
        } else {
            collectionFee = 0;
            _marketplaceFee = MarketplaceFee;
        }

        uint256 _collectionFee = (collectionFee * amount) / 100;
        uint256 mFee = (_marketplaceFee * amount) / 100;
        uint256 sellersEth = amount - _collectionFee - mFee;
        _transferPayment(collection.receipt, _collectionFee);
        _transferPayment(MarketplaceFeeCollector, mFee);
        _transferPayment(to, sellersEth);
    }

    function _transferPayment(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function setCollectionDetails(
        address nftAddress,
        uint256 _fee,
        address _receipt
    ) external onlyOwner {
        if (_fee > COLLECTION_MAX_FEE) revert AboveMaximum();
        _collection[nftAddress] = CollectionOwnerFee({
            fee: _fee,
            receipt: _receipt
        });
    }

    function setMarketplaceFee(uint256 _marketplacefee) external onlyOwner {
        if (_marketplacefee > MARKETPLACE_MAX_FEE) revert AboveMaximum();
        MarketplaceFee = _marketplacefee;
    }

    function setMarketplaceFeeCollector(address account) external onlyOwner {
        MarketplaceFeeCollector = account;
    }

    function getCollectionInfo(address nftAddress)
        external
        view
        returns (CollectionOwnerFee memory)
    {
        return _collection[nftAddress];
    }

    function getCollectionTokenInfo(address nftAddress, uint256 tokenId)
        external
        view
        returns (ListingItem memory)
    {
        return listing[nftAddress][tokenId];
    }

    ///================EVENTS================///
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event UpdateListing(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
}
