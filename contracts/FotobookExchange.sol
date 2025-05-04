// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FotobookNFT.sol";

/// @title FotobookExchange - Upgradeable helper contract for auctions and offers
/// @notice Manages auctions, offers, and ERC20 tokens for FotobookNFT
/// @dev Interacts with FotobookNFT, uses OpenZeppelin upgradeable proxy
/// @author compez.eth
/// @custom:security-contact security@genyleap.com
contract FotobookExchange is Initializable, OwnableUpgradeable {
    bool private _locked;
    FotobookNFT private _nftContract;

    modifier noReentrancy() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    struct Auction {
        address seller;
        uint256 tokenId;
        address currency;
        uint256 minBid;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(address => mapping(address => uint256)) public pendingWithdrawals;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public tokenOffers;
    mapping(address => bool) public allowedTokens;

    event AuctionStarted(uint256 indexed tokenId, address currency, uint256 minBid);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 amount);
    event OfferPlaced(uint256 indexed tokenId, address indexed offerer, address currency, uint256 amount);
    event OfferAccepted(uint256 indexed tokenId, address indexed offerer, address currency, uint256 amount);
    event TokenAdded(address indexed token);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    function initialize(address nftContract) external initializer {
        require(nftContract != address(0), "Invalid NFT contract address");
        __Ownable_init();
        _nftContract = FotobookNFT(nftContract);
    }

    /// @notice Adds an ERC20 token to the allowed list
    function addToken(address token) external onlyOwner {
        require(token != address(0) && !allowedTokens[token], "Invalid token");
        allowedTokens[token] = true;
        emit TokenAdded(token);
    }

    /// @notice Removes an ERC20 token from the allowed list
    function removeToken(address token) external onlyOwner {
        require(allowedTokens[token], "Token not allowed");
        allowedTokens[token] = false;
    }

    /// @notice Starts an auction for an NFT
    function startAuction(uint256 tokenId, address currency, uint256 minBid, uint256 duration) external noReentrancy {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!auctions[tokenId].active, "Auction already active");
        require(minBid > 0, "Minimum bid must be greater than 0");
        require(duration >= 1 hours && duration <= 30 days, "Invalid duration");
        require(currency == address(0) || allowedTokens[currency], "Currency not allowed");

        auctions[tokenId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            currency: currency,
            minBid: minBid,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        emit AuctionStarted(tokenId, currency, minBid);
    }

    /// @notice Places a bid in an active auction
    function placeBid(uint256 tokenId, uint256 amount) external payable noReentrancy {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(amount > auction.highestBid && amount >= auction.minBid, "Bid too low");

        if (auction.currency == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH not allowed");
            IERC20(auction.currency).transferFrom(msg.sender, address(this), amount);
        }

        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder][auction.currency] += auction.highestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = amount;

        emit BidPlaced(tokenId, msg.sender, amount);
    }

    /// @notice Withdraws pending bid refunds
    function withdraw(address currency) external noReentrancy {
        uint256 amount = pendingWithdrawals[msg.sender][currency];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender][currency] = 0;

        if (currency == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(currency).transfer(msg.sender, amount);
        }
    }

    /// @notice Ends an auction and transfers the NFT
    function endAuction(uint256 tokenId) external noReentrancy {
        Auction storage auction = auctions[tokenId];
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(auction.seller == msg.sender, "Not seller");

        if (auction.highestBidder != address(0)) {
            address approved = _nftContract.getApproved(tokenId);
            require(approved == address(this), "Auction contract not approved for transfer");
        }

        auction.active = false;

        if (auction.highestBidder != address(0)) {
            _nftContract.transferFrom(auction.seller, auction.highestBidder, tokenId);
            if (auction.currency == address(0)) {
                (bool success, ) = payable(auction.seller).call{value: auction.highestBid}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(auction.currency).transfer(auction.seller, auction.highestBid);
            }
            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(tokenId, address(0), 0);
        }
    }

    /// @notice Places an offer for an NFT
    function placeOffer(uint256 tokenId, address currency, uint256 amount) external payable noReentrancy {
        require(currency == address(0) || allowedTokens[currency], "Currency not allowed");
        require(amount > tokenOffers[tokenId][msg.sender][currency], "Offer must be higher");

        if (currency == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "ETH not allowed");
            IERC20(currency).transferFrom(msg.sender, address(this), amount);
        }

        tokenOffers[tokenId][msg.sender][currency] = amount;
        emit OfferPlaced(tokenId, msg.sender, currency, amount);
    }

    /// @notice Accepts an offer for an NFT
    function acceptOffer(uint256 tokenId, address offerer, address currency) external noReentrancy {
        require(_nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        uint256 offerAmount = tokenOffers[tokenId][offerer][currency];
        require(offerAmount > 0, "No offer exists");

        address approved = _nftContract.getApproved(tokenId);
        require(approved == address(this), "Auction contract not approved for transfer");

        tokenOffers[tokenId][offerer][currency] = 0;
        _nftContract.transferFrom(msg.sender, offerer, tokenId);

        if (currency == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: offerAmount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(currency).transfer(msg.sender, offerAmount);
        }

        emit OfferAccepted(tokenId, offerer, currency, offerAmount);
    }
}
