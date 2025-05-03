// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title FotobookNFT - A platform for minting, managing, and auctioning unique NFTs
/// @notice This contract allows users to mint 1/1 NFTs, set visibility, auction tokens, and place offers
/// @dev Extends ERC721Creator from Manifold, deployed on Base network
/// @author compez.eth
contract FotobookNFT is ERC721Creator {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    // Internal reentrancy guard
    bool private _locked;

    /// @notice Prevents reentrant calls to sensitive functions
    modifier noReentrancy() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    /// @notice Struct for auction details
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 minBid;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    /// @notice Struct for token visibility
    struct TokenVisibility {
        bool isPublic;
    }

    // Mappings
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => string) public tokenURIs;
    mapping(uint256 => TokenVisibility) public tokenVisibilities;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(uint256 => mapping(address => uint256)) public tokenOffers;

    // Events
    event NFTMinted(uint256 indexed tokenId, address indexed recipient, string tokenURI, bool isPublic);
    event AuctionStarted(uint256 indexed tokenId, uint256 minBid, uint256 endTime);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 amount);
    event VisibilityUpdated(uint256 indexed tokenId, bool isPublic);
    event OfferPlaced(uint256 indexed tokenId, address indexed offerer, uint256 amount);
    event OfferAccepted(uint256 indexed tokenId, address indexed offerer, uint256 amount);

    /// @notice Constructor to initialize the contract
    constructor() ERC721Creator("Fotobook", "FOTO") {}

    /// @notice Mints a new 1/1 NFT with specified URI and visibility
    /// @param recipient Address to receive the NFT
    /// @param tokenURI URI for the NFT metadata
    /// @param isPublic Whether the NFT is publicly visible
    /// @return tokenId The ID of the minted NFT
    function mintNFT(address recipient, string calldata tokenURI, bool isPublic) external noReentrancy returns (uint256) {
        require(recipient != address(0));
        require(bytes(tokenURI).length > 0);

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        mintBase(recipient, tokenURI);
        require(ownerOf(newTokenId) == recipient);

        tokenURIs[newTokenId] = tokenURI;
        tokenVisibilities[newTokenId] = TokenVisibility({isPublic: isPublic});
        emit NFTMinted(newTokenId, recipient, tokenURI, isPublic);

        return newTokenId;
    }

    /// @notice Starts an auction for an NFT
    /// @param tokenId ID of the NFT
    /// @param minBid Minimum bid amount in wei
    /// @param duration Duration of the auction in seconds
    function startAuction(uint256 tokenId, uint256 minBid, uint256 duration) external noReentrancy {
        require(ownerOf(tokenId) == msg.sender);
        require(!auctions[tokenId].active);
        require(minBid > 0);
        require(duration >= 1 hours && duration <= 30 days);

        auctions[tokenId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            minBid: minBid,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        emit AuctionStarted(tokenId, minBid, block.timestamp + duration);
    }

    /// @notice Places a bid in an active auction
    /// @param tokenId ID of the NFT being auctioned
    function placeBid(uint256 tokenId) external payable noReentrancy {
        Auction storage auction = auctions[tokenId];
        require(auction.active);
        require(block.timestamp < auction.endTime);
        require(msg.value > auction.highestBid && msg.value >= auction.minBid);

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    /// @notice Withdraws pending bid refunds
    function withdraw() external noReentrancy {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0);
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /// @notice Ends an auction and transfers the NFT to the highest bidder
    /// @param tokenId ID of the NFT being auctioned
    function endAuction(uint256 tokenId) external noReentrancy {
        Auction storage auction = auctions[tokenId];
        require(auction.active);
        require(block.timestamp >= auction.endTime);
        require(auction.seller == msg.sender);

        auction.active = false;

        if (auction.highestBidder != address(0)) {
            _transfer(auction.seller, auction.highestBidder, tokenId);
            payable(auction.seller).transfer(auction.highestBid);
            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(tokenId, address(0), 0);
        }
    }

    /// @notice Places an offer for an NFT outside of an auction
    /// @param tokenId ID of the NFT
    function placeOffer(uint256 tokenId) external payable noReentrancy {
        require(msg.value > tokenOffers[tokenId][msg.sender]);
        tokenOffers[tokenId][msg.sender] = msg.value;
        emit OfferPlaced(tokenId, msg.sender, msg.value);
    }

    /// @notice Accepts an offer for an NFT
    /// @param tokenId ID of the NFT
    /// @param offerer Address of the offerer
    function acceptOffer(uint256 tokenId, address offerer) external noReentrancy {
        require(ownerOf(tokenId) == msg.sender);
        uint256 offerAmount = tokenOffers[tokenId][offerer];
        require(offerAmount > 0);
        tokenOffers[tokenId][offerer] = 0;
        _transfer(msg.sender, offerer, tokenId);
        payable(msg.sender).transfer(offerAmount);
        emit OfferAccepted(tokenId, offerer, offerAmount);
    }

    /// @notice Updates the visibility of an NFT (public/private)
    /// @param tokenId ID of the NFT
    /// @param isPublic Whether the NFT is publicly visible
    function updateVisibility(uint256 tokenId, bool isPublic) external {
        require(ownerOf(tokenId) == msg.sender);
        tokenVisibilities[tokenId].isPublic = isPublic;
        emit VisibilityUpdated(tokenId, isPublic);
    }

    /// @notice Checks if an NFT is publicly visible
    /// @param tokenId ID of the NFT
    /// @return True if the NFT is public, false otherwise
    function isTokenPublic(uint256 tokenId) external view returns (bool) {
        return tokenVisibilities[tokenId].isPublic;
    }
}